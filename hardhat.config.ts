import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers"


const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      gas: 30000000
    },
    goerli: {
      url: "https://eth-goerli.public.blastapi.io",
      accounts: [process.env.EXTERNAL2!],
      chainId: 5,
      gas: 300000
    },
    arbitrum: {
      url: "https://arbitrum-goerli.public.blastapi.io",
      accounts: [process.env.EXTERNAL2!],
      chainId: 421613
    }
  },

  solidity: {
    version: "0.8.16",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: true,
  },

};

export default config;
