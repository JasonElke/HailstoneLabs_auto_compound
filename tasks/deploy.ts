import { task } from 'hardhat/config';
import fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();

task('deploy', 'Deploys the contract')
  .setAction(async (taskArgs, { ethers, run }) => {
    await run("compile");
    const [deployer] = await ethers.getSigners();
    const { WOM_TOKEN_ADDRESS, USDC_TOKEN_ADDRESS, LP_TOKEN_ADDRESS, MAIN_POOL_ADDRESS, MASTER_WOMBAT_V2_ADDRESS, LP_PANCAKE_V3_ADDRESS } = process.env;

    if (!WOM_TOKEN_ADDRESS || !USDC_TOKEN_ADDRESS || !LP_TOKEN_ADDRESS || !MAIN_POOL_ADDRESS || !MASTER_WOMBAT_V2_ADDRESS || !LP_PANCAKE_V3_ADDRESS) {
      console.error('Missing environment variables');
      return;
    }

    console.log('Deploying contract with the following parameters:');
    console.log(` - WOM Token Address: ${WOM_TOKEN_ADDRESS}`);
    console.log(` - USDC Token Address: ${USDC_TOKEN_ADDRESS}`);
    console.log(` - LP Token Address: ${LP_TOKEN_ADDRESS}`);
    console.log(` - Main Pool Address: ${MAIN_POOL_ADDRESS}`);
    console.log(` - MasterWombatV2 Address: ${MASTER_WOMBAT_V2_ADDRESS}`);
    console.log(` - Pancake Router Address: ${LP_PANCAKE_V3_ADDRESS}`);

    const AutoCompounder = await ethers.getContractFactory('AutoCompounder');
    const autoCompounder = await AutoCompounder.deploy(
      WOM_TOKEN_ADDRESS,
      USDC_TOKEN_ADDRESS,
      LP_TOKEN_ADDRESS,
      MAIN_POOL_ADDRESS,
      MASTER_WOMBAT_V2_ADDRESS,
      LP_PANCAKE_V3_ADDRESS
    );

    await autoCompounder.deployed();
    
    // Write auto-compounder contract address to contract.json file
    const data = JSON.stringify({ address: autoCompounder.address }, null, 2);
    fs.writeFileSync('contract.json', data);

    console.log('Contract deployed at address:', autoCompounder.address);
    console.log('Transaction hash:', autoCompounder.deployTransaction.hash);
  });

// Run the deployment task
task('run-deploy', 'Runs the contract deployment task')
  .setAction(async (taskArgs, { run }) => {
    try {
      await run('deploy');
    } catch (error) {
      console.error(error);
      process.exitCode = 1;
    }
  });
