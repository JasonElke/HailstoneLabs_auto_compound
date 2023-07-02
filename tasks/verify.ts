import { task } from 'hardhat/config';
import contractData from "../contract.json";

require('dotenv').config();

task('verify', 'Verifies the deployed contract on Bscscan')
  .setAction(async (taskArgs, { run }) => {
    const { BSCSCAN_API_KEY } = process.env;

    if ( !BSCSCAN_API_KEY) {
      console.error('Missing environment variables: BSCSCAN_API_KEY');
      return;
    }

    const { address } = contractData;

    console.log(`Verifying contract at address: ${address}`);

    try {
      await run('verify:verify', {
        address: address,
        constructorArguments: [
          process.env.WOM_TOKEN_ADDRESS!,
          process.env.USDC_TOKEN_ADDRESS!,
          process.env.LP_TOKEN_ADDRESS!,
          process.env.MAIN_POOL_ADDRESS!,
          process.env.MASTER_WOMBAT_V2_ADDRESS!,
          process.env.PANCAKE_ROUTER_ADDRESS!
        ],
        apiKey: BSCSCAN_API_KEY,
        network: 'mainnet' // Adjust for the desired network
      });

      console.log('Contract verification successful!');
    } catch (error) {
      console.error('Contract verification failed:', error);
    }
  });

// Run the script
task('run-verify', 'Runs the contract verification task')
  .setAction(async (taskArgs, { run }) => {
    try {
      await run('verify', { address: '<Deployed Contract Address>' });
    } catch (error) {
      console.error(error);
      process.exitCode = 1;
    }
  });
