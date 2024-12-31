require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require('hardhat-contract-sizer');
require('dotenv').config();

module.exports = {
  solidity: {
    version: "0.8.25",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {},
    l2: {
      url: process.env.L2_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 11155111, // Sepolia testnet chain ID
    }
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      l2: "abcd",
      bscTestnet: "abcd",
    },
    customChains: [
      {
        network: "l2_sepolia",
        chainId: process.env.L2_CHAINID,
        urls: {
            apiURL: process.env.L2_EXPLORER_API_URL,
            browserURL: process.env.L2_EXPLORER_URL,
        },
    }
    ]
  }
};
