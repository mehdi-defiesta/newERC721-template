const { ethers, run } = require("hardhat");
require('dotenv').config();

// command to run: "npx hardhat run scripts/deploy/2.deployContracts.js --network l2"

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", await deployer.getAddress());

    const balance = await ethers.provider.getBalance(await deployer.getAddress());
    console.log("Account balance:", ethers.formatEther(balance));


    // ------------------------ NFTFACTORY INSTANCE ---------------------------------


    // Instantiate the NFTFactory
    const NFTFactory = await ethers.getContractFactory("NFTFactory");
    const nftFactory = await NFTFactory.deploy();
    await nftFactory.waitForDeployment();
    console.log("NFTFactory deployed to:", nftFactory.target);

    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait for 30 seconds

    await run("verify:verify", {
        address: nftFactory.target,
        constructorArguments: [],
      });


    // ------------------------ NFTFACTORY PROXY ---------------------------------

    const NFTFactoryProxy = await ethers.getContractFactory("NFTFactoryProxy");
    const nftFactoryProxy = await NFTFactoryProxy.deploy();
    await nftFactoryProxy.waitForDeployment();
    console.log("GemFactoryProxy deployed to:", nftFactoryProxy.target);

    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait for 30 seconds

    // verifying the contract
    await run("verify:verify", {
        address: nftFactoryProxy.target,
        constructorArguments: [],
        contract:"contracts/NFTFactoryProxy.sol:NFTFactoryProxy"
      });

    // Set the first index to the GemFactory contract
    const upgradeNFTFactoryTo = await nftFactoryProxy.upgradeTo(gemFactory.target);
    await upgradeNFTFactoryTo.wait();
    console.log("NFTFactoryProxy upgraded to NFTFactory");

    // ------------------------ TREASURY INSTANCE ---------------------------------
    
    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy();
    await treasury.waitForDeployment();
    console.log("Treasury deployed to:", treasury.target);

    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait for 30 seconds

    await run("verify:verify", {
      address: treasury.target,
      constructorArguments: [],
      contract:"contracts/Treasury.sol:Treasury"
    });

    // ------------------------ TREASURY PROXY INSTANCE ---------------------------------

    const TreasuryProxy = await ethers.getContractFactory("TreasuryProxy");
    const treasuryProxy = await TreasuryProxy.deploy();
    await treasuryProxy.waitForDeployment(); // Ensure deployment is complete
    console.log("TreasuryProxy deployed to:", treasuryProxy.target);

    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait for 30 seconds

    // Verify Treasury
    await run("verify:verify", {
      address: treasuryProxy.target,
      constructorArguments: [],
      contract:"contracts/TreasuryProxy.sol:TreasuryProxy"
    });
    console.log("TreasuryProxy verified");

    // Set the first index to the GemFactory contract
    const upgradeTreasuryTo = await treasuryProxy.upgradeTo(treasury.target);
    await upgradeTreasuryTo.wait();
    console.log("treasuryProxy upgraded to Treaury");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
