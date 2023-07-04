// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@pancakeswap/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import "./interfaces/IMainPool.sol";
import "./interfaces/IMasterWombatV2.sol";


contract AutoCompounder {
    using SafeERC20 for IERC20;

    // User deposit event
    event Deposit(address indexed user, uint256 amountUSDC, uint256 amountLP);

    // User withdraw event
    event Withdraw(address indexed user, uint256 amountUSDC, uint256 amountLP);

    //The maximum tick that get from TickMath libraries
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    IERC20 public womTokenContract; // WOM token instance
    IERC20 public usdcTokenContract; // USDC token instance
    IERC20 public lpTokenContract; // LP token instance
    IMainPool public mainPoolContract; // MainPool contract instance
    IMasterWombatV2 public masterWombatV2Contract; // MasterWombatV2 contract instance
    IPancakeV3Pool public lpPool; // USDC-WOM pool


    struct DepositInfo {
        uint256 amountUSDCDeposited; // amount of deposited USDC 
        uint256 compoundUSDCBalance; // amount of compounded USDC 
        uint256 amountLPDeposited; // amount of LP corresponding to deposited USDC
        uint256 compoundLPBalance; // amount of compounded LP corresponding to compounded  USDC
    }
    
    mapping(address => DepositInfo) public deposits;
    address[] public depositAddresses;
    mapping(address => bool) public isUserIncluded;

    uint256 totalDepositedUSDC; // total deposited USDC 
    uint256 totalDepositedLP; // total deposited LP 

    constructor(address _womToken, address _usdcToken, address _lpToken, address _mainPool, address _masterWombatV2, address _lpPool ) {
        womTokenContract = IERC20(_womToken);
        usdcTokenContract = IERC20(_usdcToken);
        lpTokenContract = IERC20(_lpToken);
        mainPoolContract = IMainPool(_mainPool);
        masterWombatV2Contract = IMasterWombatV2(_masterWombatV2);
        lpPool = IPancakeV3Pool(_lpPool);

        // Approve MainPool to spend USDC
        usdcTokenContract.safeApprove(address(mainPoolContract), type(uint256).max);
        // Approve masterWombatV2Contract to spend LP
        lpTokenContract.safeApprove(address(masterWombatV2Contract), type(uint256).max);
    }

    function deposit(uint256 amount) external returns (uint256 liquidity){
        // Assert sufficient USDC balance 
        require(usdcTokenContract.balanceOf(msg.sender) >= amount, "Insufficient USDC balance!");

        // Check contract have deposited user or not in order to compound before handle depositing
        if(depositAddresses.length > 0){
            compound();
        }

        // Transfer USDC to Auto Compound Contract
        usdcTokenContract.safeTransferFrom(msg.sender, address(this), amount);

        // Deposit USDC to MainPool 
        liquidity = mainPoolContract.deposit(address(usdcTokenContract), amount, 0, address(this), block.timestamp + 1000, false);

        // Get USDC pool id and stake LP tokens to MasterWombatV2
        masterWombatV2Contract.deposit(masterWombatV2Contract.getAssetPid(address(lpTokenContract)), liquidity);

        // Update the user's deposit balance
        DepositInfo storage depositInfo = deposits[msg.sender];
        depositInfo.amountUSDCDeposited += amount;
        depositInfo.amountLPDeposited += liquidity;
        
        // Add the user to the depositAddresses array if they are not already included
        if (!isUserIncluded[msg.sender]) {
            depositAddresses.push(msg.sender);
            isUserIncluded[msg.sender] = true;
        }

        // Update deposited total
        totalDepositedUSDC += amount;
        totalDepositedLP += liquidity;

        // Trigger event Deposit
        emit Deposit(msg.sender, amount, liquidity);
    }

    function compound() public {
        // Get USDC token pool id from MasterWombatV2
        uint256 lpPoolId = masterWombatV2Contract.getAssetPid(address(lpTokenContract));

        // Update pool for calculating pending WOM reward
        masterWombatV2Contract.updatePool(lpPoolId);

        // Harvest WOM rewards from MasterWombatV2
        (uint256 womReward, ) = masterWombatV2Contract.withdraw(lpPoolId, 0);

        if(womReward != 0){
            // Call swap in lP USDC-WOM 
            lpPool.swap(address(this), false, int256(womReward), MAX_SQRT_RATIO - 1, abi.encode(address(this)));
        }

        // store USDC contract balance for calculate compound
        uint256 usdcBalance = usdcTokenContract.balanceOf(address(this));

        // Compound the obtained USDC back to the Main pool
        uint256 liquidity = mainPoolContract.deposit(address(usdcTokenContract), usdcBalance, 0, address(this), block.timestamp + 1000 , false);

        // Compound the LP tokens back to MasterWombatV2
        masterWombatV2Contract.deposit(lpPoolId, liquidity);

        // Update the compound balance for each user
        if(depositAddresses.length > 0){
            for (uint256 i = 0; i < depositAddresses.length; i++) {
                address user = depositAddresses[i];
                DepositInfo storage depositInfo = deposits[user];
                // Calculate USDC and LP compound balance
                depositInfo.compoundUSDCBalance = depositInfo.compoundUSDCBalance + (usdcBalance * depositInfo.amountUSDCDeposited/totalDepositedUSDC);
                depositInfo.compoundLPBalance = depositInfo.compoundLPBalance + (liquidity * depositInfo.amountLPDeposited/totalDepositedLP);
            }
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

        uint256 lpPoolId = masterWombatV2Contract.getAssetPid(address(lpTokenContract));
        uint256 totalUserLP = depositInfo.amountLPDeposited + depositInfo.compoundLPBalance;

        // Unstake deposited and compounded LP tokens
        (uint256 womReward, ) = masterWombatV2Contract.withdraw(lpPoolId, totalUserLP);
        
        if(womReward != 0){
            // Call swap in lP USDC-WOM 
            lpPool.swap(address(this), false, int256(womReward), MAX_SQRT_RATIO - 1, abi.encode(address(this)));
        }

        // store USDC contract balance for calculate compound
        uint256 usdcBalance = usdcTokenContract.balanceOf(address(this));

        // Withdraw USDC from MainPool and transfer to sender
        uint256 unstakeUSDC = mainPoolContract.withdraw(address(usdcTokenContract), totalUserLP, 0, msg.sender, block.timestamp + 1);
        totalUSDC = usdcBalance + unstakeUSDC;

        // Update the sender's deposit info
        if(depositAddresses.length > 0){
            delete deposits[msg.sender];
            for (uint256 i = 0; i < depositAddresses.length; i++) {
                if(depositAddresses[i] == msg.sender){
                    depositAddresses[i] = depositAddresses[depositAddresses.length - 1];
                    depositAddresses.pop();
                    break;
                }         
            }
            delete isUserIncluded[msg.sender];
        }

        emit Withdraw(msg.sender, totalUSDC, totalUserLP);
    }

    function getUserDepositInfo(address user) public view returns (uint256 amountUSDC, uint256 compoundUSDC, uint256 amountLP, uint256 compoundLP) {
        DepositInfo storage depositInfo = deposits[user];
        amountUSDC = depositInfo.amountUSDCDeposited;
        compoundUSDC = depositInfo.compoundUSDCBalance;
        amountLP = depositInfo.amountLPDeposited;
        compoundLP = depositInfo.compoundLPBalance;
    }
    
}
