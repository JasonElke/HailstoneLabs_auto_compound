import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';
import { expect } from 'chai';
import contractData from '../contract.json'
import dotenv from 'dotenv';
dotenv.config();

describe('AutoCompounder', () => {
  let autoCompounder: Contract;
  let signer: Signer;
  const {BSC_TESTNET_URL, PRIVATE_KEY, WOM_TOKEN_ADDRESS, USDC_TOKEN_ADDRESS, LP_TOKEN_ADDRESS, MAIN_POOL_ADDRESS, MASTER_WOMBAT_V2_ADDRESS, PANCAKE_ROUTER_ADDRESS } = process.env;
  if (!BSC_TESTNET_URL || !PRIVATE_KEY || !WOM_TOKEN_ADDRESS || !USDC_TOKEN_ADDRESS || !LP_TOKEN_ADDRESS || !MAIN_POOL_ADDRESS || !MASTER_WOMBAT_V2_ADDRESS || !PANCAKE_ROUTER_ADDRESS) {
    console.error('Missing environment variables');
    return;
  }
  beforeEach(async () => {
    // connect to BSC Testnet
    const provider = new ethers.providers.JsonRpcProvider(BSC_TESTNET_URL);
    
    // Get signer address from private key
    signer = new ethers.Wallet(PRIVATE_KEY, provider);

    const AutoCompounder = await ethers.getContractFactory('AutoCompounder');
    autoCompounder = await AutoCompounder.attach(
      // Provide the contract address here
      contractData.address
    );

    await autoCompounder.deployed();
    
  });

  it('should deposit USDC into MainPool and stake LP tokens to MasterWombatV2', async () => {
    const depositAmount = 100;

    // Get the initial USDC balance of signer
    const usdcToken = await ethers.getContractAt('IERC20', USDC_TOKEN_ADDRESS, signer);
    const initialUSDCBalance = await usdcToken.balanceOf(await signer.getAddress());

    // Approve USDC transfer from signer to AutoCompounder contract
    await usdcToken.approve(autoCompounder.address, depositAmount);

    // Deposit USDC into AutoCompounder contract
    const [amountUSDC, amountLP] = await autoCompounder.connect(signer).deposit(depositAmount);

    // Check the deposit event was emitted
    const depositEvent = await autoCompounder.queryFilter(autoCompounder.filters.Deposit());
    expect(depositEvent.length).to.equal(1);

    // Check the deposit balances
    const [amountUSDCDeposited, amountLPDeposited] = await autoCompounder.getUserDepositInfo(await signer.getAddress());
    expect(amountUSDCDeposited).to.equal(amountUSDC);
    expect(amountLPDeposited).to.equal(amountLP);

    // Get the final USDC balance of signer
    const finalUSDCBalance = await usdcToken.balanceOf(await signer.getAddress());

    // Check if the USDC balance has decreased due to the deposit
    expect(finalUSDCBalance).to.equal(initialUSDCBalance.sub(depositAmount));
  });

  it('should compound WOM rewards and update user balances', async () => {
    const depositAmount = 100;

    // Get the initial USDC balance of signer
    const usdcToken = await ethers.getContractAt('IERC20', USDC_TOKEN_ADDRESS, signer);
    const initialUSDCBalance = await usdcToken.balanceOf(await signer.getAddress());

    // Approve USDC transfer from signer to AutoCompounder contract
    await usdcToken.approve(autoCompounder.address, depositAmount);

    // Deposit USDC into AutoCompounder contract
    await autoCompounder.connect(signer).deposit(depositAmount);

    // Check the deposit event was emitted
    const depositEvent = await autoCompounder.queryFilter(autoCompounder.filters.Deposit());
    expect(depositEvent.length).to.equal(1);

    // Trigger compound function
    await autoCompounder.compound();

    // Check the deposit balances after compounding
    const [amountUSDCDeposited, compoundUSDCBalance, amountLPDeposited, compoundLPBalance] = await autoCompounder.getUserDepositInfo(await signer.getAddress());
    expect(amountUSDCDeposited).to.equal(depositAmount);
    expect(compoundUSDCBalance).to.be.greaterThan(0);
    expect(amountLPDeposited).to.be.greaterThan(0);
    expect(compoundLPBalance).to.be.greaterThan(0);

    // Get the final USDC balance of signer
    const finalUSDCBalance = await usdcToken.balanceOf(await signer.getAddress());

    // Check if the USDC balance remains the same after compounding
    expect(finalUSDCBalance).to.equal(initialUSDCBalance.sub(depositAmount));
  });

  it('should withdraw funds from AutoCompounder and transfer USDC back to the user', async () => {
    const depositAmount = 100;

    // Get the initial USDC balance of signer
    const usdcToken = await ethers.getContractAt('IERC20', USDC_TOKEN_ADDRESS, signer);
    
    // Approve USDC transfer from signer to AutoCompounder contract
    await usdcToken.approve(autoCompounder.address, depositAmount);

    // Deposit USDC into AutoCompounder contract
    await autoCompounder.connect(signer).deposit(depositAmount);

    // Trigger compound function
    await autoCompounder.compound();

    // Get the initial USDC balance of signer before withdrawal
    const initialUSDCBalanceBeforeWithdrawal = await usdcToken.balanceOf(await signer.getAddress());

    // Withdraw funds from AutoCompounder contract
    const totalUSDC = await autoCompounder.connect(signer).withdraw();

    // Check the withdraw event was emitted
    const withdrawEvent = await autoCompounder.queryFilter(autoCompounder.filters.Withdraw());
    expect(withdrawEvent.length).to.equal(1);

    // Check the deposit balances after withdrawal
    const [amountUSDCDeposited, compoundUSDCBalance, amountLPDeposited, compoundLPBalance] = await autoCompounder.getUserDepositInfo(await signer.getAddress());
    expect(amountUSDCDeposited).to.equal(0);
    expect(compoundUSDCBalance).to.equal(0);
    expect(amountLPDeposited).to.equal(0);
    expect(compoundLPBalance).to.equal(0);

    // Get the final USDC balance of signer after withdrawal
    const finalUSDCBalance = await usdcToken.balanceOf(await signer.getAddress());

    // Check if the USDC balance has increased after withdrawal
    expect(finalUSDCBalance).to.equal(initialUSDCBalanceBeforeWithdrawal.add(totalUSDC));
  });
});