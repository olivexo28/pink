require('dotenv').config();
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  try {
    const PinkSaltToken = await ethers.getContractFactory("PinkSaltTokenV1");
    const walletAddresses = {
      saltFeeWallet: process.env.SALT_FEE_WALLET,
      foundersWallet: process.env.FOUNDERS_WALLET,
      publicTradeWallet: process.env.PUBLIC_TRADE_WALLET,
      airdropWallet: process.env.AIRDROP_WALLET,
      developmentWallet: process.env.DEVELOPMENT_WALLET,
      rewardWallet: process.env.REWARD_WALLET,
      deploymentWallet: deployer.address,
    };
    const priceFeedAddresses = {
      priceFeedBNB: process.env.PRICE_FEED_BNB,
      priceFeedPSC: process.env.PRICE_FEED_PSC,
      uniswapRouter: process.env.UNISWAP_ROUTER,
    };

    const psc = await upgrades.deployProxy(PinkSaltToken, [
      "Pink Salt Token", 
      "PSC",
      walletAddresses,
      priceFeedAddresses
    ], { initializer: 'initialize' });

    await psc.deployed();

    console.log("Pink Salt Token (PSC) deployed to:", psc.address);
  } catch (error) {
    console.error("Deployment failed:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });