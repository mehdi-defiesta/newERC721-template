const { ethers } = require("hardhat");
require('dotenv').config();
// command to run: "source .env"
// command to run: "npx hardhat run scripts/deploy/3.Initialization.js --network l2"

async function main() {
  const [deployer] = await ethers.getSigners();

  
  // Fetch environment variables
  const nftFactoryAddress = process.env.NFT_FACTORY;

  const nftFactoryProxyAddress = process.env.NFT_FACTORY_PROXY;
  const treasuryAddress = process.env.TREASURY;
  const treasuryProxyAddress = process.env.TREASURY_PROXY;

  const owner = "0x5c5c36Bb1e3B266637F6830FCAe2Ee2715339Eb1" // to be updated
  
  if (!nftFactoryAddress || !nftFactoryProxyAddress||  !treasuryAddress) {
    throw new Error("Environment variables NFT_FACTORY, NFT_FACTORY_PROXY andTREASURY must be set");
  }
  
  // Get contract instances
  const NFTFactory = await ethers.getContractAt("NFTFactory", nftFactoryProxyAddress);
  const Treasury = await ethers.getContractAt("Treasury", treasuryProxyAddress);

  // ---------------------------- NFTFACTORYPROXY INITIALIZATION ---------------------------------

  // Initialize NFTFactory with newly created contract addresses
  const initializeTx = await NFTFactory.initialize(
    "NFT Wston", // to update 
    "NFTWSTON", // to update
    owner,
    process.env.L2_WSTON_ADDRESS,
    treasuryProxyAddress,
    { gasLimit: 10000000 }
  );
  await initializeTx.wait();
  console.log("NFTFactoryProxy initialized");


  // ---------------------------- TREASURYPROXY INITIALIZATION ---------------------------------
  // Attach the Treasury interface to the TreasuryProxy contract address
  console.log("treasury initialization...");
  // Call the Treasury initialize function
  const tx2 = await Treasury.initialize(
    process.env.L2_WSTON_ADDRESS, // l2wston
    nftFactoryProxyAddress
  );
  await tx2.wait();
  console.log("TreasuryProxy initialized");

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
