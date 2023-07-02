import { HardhatUserConfig } from 'hardhat/types';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@typechain/hardhat';
import 'solidity-coverage';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import glob from 'glob';
import path from 'path';
import * as dotenv from 'dotenv';
dotenv.config();

glob.sync('./tasks/**/*.ts').forEach(function (file) {
  require(path.resolve(file));
});

const config: HardhatUserConfig = {
  solidity: '0.8.7',
  networks: {
    bscTestnet: {
      url: process.env.BSC_TESTNET_URL || '',
      accounts: [process.env.PRIVATE_KEY || ''],
    },
  },
  
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY || '',
  },
  gasReporter: {
    enabled: true,
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },
};

export default config;
