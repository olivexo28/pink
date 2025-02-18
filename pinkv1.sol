// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PinkSaltToken is ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant TOTAL_SUPPLY = 500_000_000 * 10 ** 18;
    uint256 public constant PUBLIC_TRADE_SUPPLY = 300_000_000 * 10 ** 18;
    uint256 public constant DEV_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant AIRDROP_SUPPLY = 25_000_000 * 10 ** 18;
    uint256 public constant REWARD_SUPPLY = 25_000_000 * 10 ** 18;
    uint256 public constant FOUNDER_SUPPLY = 50_000_000 * 10 ** 18;

    // Wallet Allocations
    address public tradeWallet;
    address public devWallet;
    address public airdropWallet;
    address public rewardWallet;
    address public founderWallet;
    address public saltFeesWallet;
    address public uniswapRouter;
    address public liquidityPair;

    // ✅ WBNB address for Binance Smart Chain
    address public constant WBNB_ADDRESS = 0xBB4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    AggregatorV3Interface internal priceFeed;
    bool public sellEnabled;
    bool public rewardEnabled;
    bool public airdropEnabled;

    event LiquidityUpdated(uint256 newPSCAmount, uint256 newBNBAmount, uint256 newPrice);
    event RewardClaimed(address indexed user, uint256 amount, uint256 fee);
    event AirdropClaimed(address indexed user, uint256 amount, uint256 fee);

    function initialize(
        address _tradeWallet,
        address _devWallet,
        address _airdropWallet,
        address _rewardWallet,
        address _founderWallet,
        address _saltFeesWallet,
        address _uniswapRouter,
        address _priceFeed
    ) public initializer {
        __ERC20_init("Pink Salt Token", "PSC");
        __Ownable_init();
        __UUPSUpgradeable_init();

        tradeWallet = _tradeWallet;
        devWallet = _devWallet;
        airdropWallet = _airdropWallet;
        rewardWallet = _rewardWallet;
        founderWallet = _founderWallet;
        saltFeesWallet = _saltFeesWallet;
        uniswapRouter = _uniswapRouter;
        priceFeed = AggregatorV3Interface(_priceFeed);

        _mint(tradeWallet, PUBLIC_TRADE_SUPPLY);
        _mint(devWallet, DEV_SUPPLY);
        _mint(airdropWallet, AIRDROP_SUPPLY);
        _mint(rewardWallet, REWARD_SUPPLY);
        _mint(founderWallet, FOUNDER_SUPPLY);
        
        sellEnabled = false;
        rewardEnabled = false;
        airdropEnabled = false;
    }

    function enableSell() external onlyOwner {
        require(!sellEnabled, "Sell function can only be enabled once");
        sellEnabled = true;
    }

    function getPSCPriceInBNB(uint256 amountPSC) public view returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);

        // ✅ Declare and initialize `path` properly
        address;
        path[0] = address(this);  // PSC token address
        path[1] = WBNB_ADDRESS;   // ✅ WBNB address on BSC

        uint256[] memory amounts = router.getAmountsOut(amountPSC, path);
        return amounts[1];
    }

    function buyPSC() external payable {
        require(msg.value > 0, "BNB required to buy PSC");
        
        uint256 fee = (msg.value * 15) / 1000;
        uint256 liquidityAmount = msg.value - fee;

        payable(saltFeesWallet).transfer(fee);

        uint256 pscAmount = getPSCPriceInBNB(liquidityAmount);
        _transfer(tradeWallet, msg.sender, pscAmount);

        uint256 extraPSC = (pscAmount * 80) / 100;
        uint256 totalPSCToLiquidity = pscAmount + extraPSC;
        _transfer(tradeWallet, liquidityPair, totalPSCToLiquidity);

        emit LiquidityUpdated(totalPSCToLiquidity, liquidityAmount, getPSCPriceInBNB(1 ether));
    }

    function claimReward() external payable {
        require(rewardEnabled, "Rewards are currently disabled");
        require(balanceOf(msg.sender) > 0, "No PSC balance");

        uint256 requiredBNB = getBNBPrice();
        require(msg.value >= requiredBNB, "Insufficient BNB sent for fees");

        payable(saltFeesWallet).transfer(msg.value);

        uint256 rewardAmount = balanceOf(msg.sender) >= 100000 * 10 ** 18 ? 1000 * 10 ** 18 : 500 * 10 ** 18;
        require(balanceOf(rewardWallet) >= rewardAmount, "Insufficient reward balance");

        _transfer(rewardWallet, msg.sender, rewardAmount);
        emit RewardClaimed(msg.sender, rewardAmount, msg.value);
    }

    function claimAirdrop() external payable {
        require(airdropEnabled, "Airdrops are currently disabled");
        require(balanceOf(msg.sender) > 0, "No PSC balance");

        uint256 requiredBNB = getBNBPrice();
        require(msg.value >= requiredBNB, "Insufficient BNB sent for fees");

        payable(saltFeesWallet).transfer(msg.value);

        uint256 airdropAmount = balanceOf(msg.sender) >= 100000 * 10 ** 18 ? 1000 * 10 ** 18 : 500 * 10 ** 18;
        require(balanceOf(airdropWallet) >= airdropAmount, "Insufficient airdrop balance");

        _transfer(airdropWallet, msg.sender, airdropAmount);
        emit AirdropClaimed(msg.sender, airdropAmount, msg.value);
    }

    function getBNBPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * 10 ** 10;
    }

    function depositBNB() external payable {
        require(msg.sender == saltFeesWallet, "Only Salt Fees Wallet can deposit BNB");
    }

    function withdrawBNB(uint256 amount, address recipient) external {
        require(msg.sender == saltFeesWallet, "Only Salt Fees Wallet can withdraw BNB");
        require(address(this).balance >= amount, "Insufficient BNB balance");
        require(recipient != address(0), "Invalid recipient address");
        payable(recipient).transfer(amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(tradeWallet, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}
