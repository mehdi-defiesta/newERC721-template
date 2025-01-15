const { ethers, run } = require("hardhat");
require('dotenv').config();

// command to run: "npx hardhat run scripts/deploy/1.deployL2Wston.js --network l2"

async function main() {
    const [deployer] = await ethers.getSigners();

    const l2Bridge = process.env.L2_BRIDGE;
    const l1Token = process.env.L1_WRAPPED_STAKED_TON_PROXY;

    console.log("Deploying contracts with the account:", await deployer.getAddress());

    const balance = await ethers.provider.getBalance(await deployer.getAddress());
    console.log("Account balance:", ethers.formatEther(balance));

    // ------------------------ L2TitanWrappedStakedTon Deployment ---------------------------------
    
    // Instantiate the L2StandardERC20
    const L2Wston = await ethers.getContractFactory("L2StandardERC20");
    const l2Wston = await L2Wston.deploy(
        l2Bridge,
        l1Token,
        "L2 Wston",
        "L2WSTON"
    );
    await l2Wston.waitForDeployment();
    console.log("L2 Wston deployed to:", l2Wston.target);

    await new Promise(resolve => setTimeout(resolve, 30000)); // Wait for 30 seconds

    await run("verify:verify", {
        address: l2Wston.target,
        constructorArguments: [
            l2Bridge,
            l1Token,
            "L2 Wston",
            "L2WSTON"
        ],
        contract: "src/L2/L2StandardERC20.sol:L2StandardERC20"
    });

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
