// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@pancakeswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./interfaces/IMainPool.sol";
import "./interfaces/IMasterWombatV2.sol";

contract AutoCompounder {
    using SafeERC20 for IERC20;

    // User deposit event
    event Deposit(address indexed user, uint256 amountUSDC, uint256 amountLP);

    // User withdraw event
    event Withdraw(address indexed user, uint256 amountUSDC, uint256 amountLP);

    IERC20 public immutable womTokenContract; // WOM token instance
    IERC20 public immutable usdcTokenContract; // USDC token instance
    IERC20 public immutable lpTokenContract; // LP token instance
    IMainPool public immutable mainPoolContract; // MainPool contract instance
    IMasterWombatV2 public immutable masterWombatV2Contract; // MasterWombatV2 contract instance
    ISwapRouter public immutable swapRouter; // swapRouter contract instance

    struct DepositInfo {
        uint256 amountUSDCDeposited; // amount of deposited USDC 
        uint256 compoundUSDCBalance; // amount of compounded USDC 
        uint256 amountLPDeposited; // amount of LP corresponding to deposited USDC
        uint256 compoundLPBalance; // amount of compounded LP corresponding to compounded  USDC
    }
    
    mapping(address => DepositInfo) public deposits;
    address[] public depositAddresses;
    mapping(address => bool) public isUserIncluded;

    constructor(address _womToken, address _usdcToken, address _lpToken, address _mainPool, address _masterWombatV2, address _pancakeRouter ) {
        womTokenContract = IERC20(_womToken);
        usdcTokenContract = IERC20(_usdcToken);
        lpTokenContract = IERC20(_lpToken);
        mainPoolContract = IMainPool(_mainPool);
        masterWombatV2Contract = IMasterWombatV2(_masterWombatV2);
        swapRouter = ISwapRouter(_pancakeRouter);
    }

    function deposit(uint256 amount) external returns (uint256, uint256){
        // Assert sufficient USDC balance 
        require(usdcTokenContract.balanceOf(msg.sender) >= amount, "Insufficient USDC balance!");

        // Check contract have deposited user or not in order to compound before handle depositing
        if(depositAddresses.length > 0){
            compound();
        }

        // Deposit USDC into MainPool
        uint256 liquidity = mainPoolContract.deposit(address(usdcTokenContract), amount, 0, address(this), block.timestamp + 1000, false);

        // Get USDC pool id and stake LP tokens to MasterWombatV2
        masterWombatV2Contract.deposit(masterWombatV2Contract.getAssetPid(address(mainPoolContract)), liquidity);

        // Update the user's deposit balance
        DepositInfo storage depositInfo = deposits[msg.sender];
        depositInfo.amountUSDCDeposited += amount;
        depositInfo.amountLPDeposited += liquidity;
        
        // Add the user to the depositAddresses array if they are not already included
        if (!isUserIncluded[msg.sender]) {
            depositAddresses.push(msg.sender);
            isUserIncluded[msg.sender] = true;
        }

        // Trigger event Deposit
        emit Deposit(msg.sender, amount, liquidity);
        return (amount, liquidity);
    }

    function compound() public {
        // Get USDC token pool id from MasterWombatV2
        uint256 usdcPoolId = masterWombatV2Contract.getAssetPid(address(usdcTokenContract));

        // Update pool for calculating pending WOM reward
        masterWombatV2Contract.updatePool(usdcPoolId);

        // Harvest WOM rewards from MasterWombatV2
        (uint256 womReward, ) = masterWombatV2Contract.withdraw(usdcPoolId, 0);

        // Approve the Router to spend WOM
        womTokenContract.safeApprove(address(swapRouter), type(uint256).max);

        // Call the swap function in PancakeSwap contract 
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(womTokenContract),
            tokenOut: address(usdcTokenContract),
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp + 1,
            amountIn: womReward,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);

        // Compound the obtained USDC back to the Main pool
        uint256 liquidity = mainPoolContract.deposit(address(usdcTokenContract), amountOut, 0, address(this), block.timestamp + 1000 , false);

        // Compound the LP tokens back to MasterWombatV2
        masterWombatV2Contract.deposit(usdcPoolId, liquidity);

        // Update the compound balance for each user
        (uint256 totalUSDCDeposited, uint256 totalLPDeposited)= totalDeposits();
        for (uint256 i = 0; i < depositAddresses.length; i++) {
            address user = depositAddresses[i];
            DepositInfo storage depositInfo = deposits[user];
            // Calculate USDC and LP compound balance
            depositInfo.compoundUSDCBalance = depositInfo.compoundUSDCBalance + (amountOut * depositInfo.amountUSDCDeposited/totalUSDCDeposited);
            depositInfo.compoundLPBalance = depositInfo.compoundLPBalance + (liquidity * depositInfo.amountLPDeposited/totalLPDeposited);
        }
    }

    function withdraw() external returns (uint256 totalUSDC) {
        DepositInfo storage depositInfo = deposits[msg.sender];

        // Assert user deposited or not 
        require(depositInfo.amountUSDCDeposited > 0, "No deposits to withdraw!");

        // Check contract have deposited user or not in order to compound before handle depositing
        if(depositAddresses.length > 0){
            compound();
        }


        uint256 usdcPoolId = masterWombatV2Contract.getAssetPid(address(usdcTokenContract));
        uint256 totalUserLP = depositInfo.amountLPDeposited + depositInfo.compoundLPBalance;

        // Unstake deposited and compounded LP tokens
        (uint256 womReward, ) = masterWombatV2Contract.withdraw(usdcPoolId, totalUserLP);
        
        // Swap WOM to USDC and transfer to sender
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(womTokenContract),
            tokenOut: address(usdcTokenContract),
            fee: 3000, // 0.3%
            recipient: msg.sender,
            deadline: block.timestamp + 1,
            amountIn: womReward,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);

        // Withdraw USDC from MainPool and transfer to sender
        uint256 unstakeUSDC = mainPoolContract.withdraw(address(usdcTokenContract), totalUserLP, 0, msg.sender, block.timestamp + 1);
        totalUSDC = amountOut + unstakeUSDC;

        // Update the sender's deposit info
        delete deposits[msg.sender];
        for (uint256 i = 0; i < depositAddresses.length; i++) {
            if(depositAddresses[i] == msg.sender){
                depositAddresses[i] = depositAddresses[depositAddresses.length - 1];
                depositAddresses.pop();
                break;
            }         
        }
        delete isUserIncluded[msg.sender];

        emit Withdraw(msg.sender, totalUSDC, totalUserLP);
    }

    function totalDeposits() public view returns (uint256 totalUSDC, uint256 totalLP) {
        for (uint256 i = 0; i < depositAddresses.length; i++) {
            address user = depositAddresses[i];
            totalUSDC += deposits[user].amountUSDCDeposited;
            totalLP += deposits[user].amountLPDeposited;           
        }
    }

    function getUserDepositInfo(address user) public view returns (uint256 amountUSDC, uint256 compoundUSDC, uint256 amountLP, uint256 compoundLP) {
        DepositInfo storage depositInfo = deposits[user];
        amountUSDC = depositInfo.amountUSDCDeposited;
        compoundUSDC = depositInfo.compoundUSDCBalance;
        amountLP = depositInfo.amountLPDeposited;
        compoundLP = depositInfo.compoundLPBalance;
    }
    
}
