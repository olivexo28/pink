require('dotenv').config();
require("@nomicfoundation/hardhat-chai-matchers");
const { ethers, upgrades } = require("hardhat");

describe("Pink Salt Token (PSC)", function () {
  let PinkSaltToken, psc, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    PinkSaltToken = await ethers.getContractFactory("PinkSaltTokenV1");
    const walletAddresses = {
      saltFeeWallet: process.env.SALT_FEE_WALLET,
      foundersWallet: process.env.FOUNDERS_WALLET,
      publicTradeWallet: process.env.PUBLIC_TRADE_WALLET,
      airdropWallet: process.env.AIRDROP_WALLET,
      developmentWallet: process.env.DEVELOPMENT_WALLET,
      rewardWallet: process.env.REWARD_WALLET,
      deploymentWallet: owner.address,
    };
    const priceFeedAddresses = {
      priceFeedBNB: process.env.PRICE_FEED_BNB,
      priceFeedPSC: process.env.PRICE_FEED_PSC,
      uniswapRouter: process.env.UNISWAP_ROUTER,
    };

    psc = await upgrades.deployProxy(PinkSaltToken, [
      "Pink Salt Token", 
      "PSC",
      walletAddresses,
      priceFeedAddresses
    ], { initializer: 'initialize' });

    await psc.waitForDeployment();
  });

  it("Should set the right owner", async function () {
    const { expect } = await import("chai");
    expect(await psc.owner()).to.equal(owner.address);
  });

  it("Should fail when non-owner tries to enable sale", async function () {
    const { expect } = await import("chai");
    await expect(psc.connect(addr1).enableSale()).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("Should enable sale when called by owner", async function () {
    const { expect } = await import("chai");
    await psc.enableSale();
    expect(await psc.saleEnabled()).to.be.true;
  });
});