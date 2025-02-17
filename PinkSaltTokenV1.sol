// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract PinkSaltTokenV1 is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public constant TOTAL_SUPPLY = 500_000_000 * 10 ** 18; // 500 million tokens
    uint256 public constant PUBLIC_TRADE_SUPPLY = 300_000_000 * 10 ** 18; // 300 million tokens
    uint256 public constant FOUNDERS_SUPPLY = 50_000_000 * 10 ** 18; // 50 million tokens
    uint256 public constant DEVELOPMENT_SUPPLY = 100_000_000 * 10 ** 18; // 100 million tokens
    uint256 public constant REWARD_SUPPLY = 25_000_000 * 10 ** 18; // 25 million tokens
    uint256 public constant COMMUNITY_AIRDROP_SUPPLY = 25_000_000 * 10 ** 18; // 25 million tokens

    struct WalletAddresses {
        address saltFeeWallet;
        address foundersWallet;
        address publicTradeWallet;
        address airdropWallet;
        address developmentWallet;
        address rewardWallet;
        address deploymentWallet;
    }

    struct PriceFeedAddresses {
        address priceFeedBNB;
        address priceFeedPSC;
        address uniswapRouter;
    }

    WalletAddresses public walletAddresses;
    PriceFeedAddresses public priceFeedAddresses;

    bool public saleEnabled;
    bool public saleEnabledOnce;
    uint256 public totalLiquidity;
    uint256 public totalPscTokensInLiquidity;

    AggregatorV3Interface internal priceFeedBNB;
    AggregatorV3Interface internal priceFeedPSC;
    IUniswapV2Router02 public uniswapRouter;

    modifier onlyAuthorizedSwappers(address sender, uint256 amount) {
        require(
            (sender == walletAddresses.foundersWallet && amount <= 5000 * 10 ** 18) ||
            (sender == walletAddresses.developmentWallet && amount <= 2500 * 10 ** 18),
            "Not authorized to swap or amount exceeds limit"
        );
        _;
    }

    function initialize(
        string memory name, 
        string memory symbol,
        WalletAddresses memory _walletAddresses,
        PriceFeedAddresses memory _priceFeedAddresses
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __ReentrancyGuard_init();

        walletAddresses = _walletAddresses;
        priceFeedAddresses = _priceFeedAddresses;

        // Allocate the initial supplies to respective addresses
        _mintTokens();

        // Initialize other state variables
        _initializeStateVariables();
    }

    function _mintTokens() internal {
        _mint(walletAddresses.publicTradeWallet, PUBLIC_TRADE_SUPPLY);
        _mint(walletAddresses.foundersWallet, FOUNDERS_SUPPLY);
        _mint(walletAddresses.developmentWallet, DEVELOPMENT_SUPPLY);
        _mint(walletAddresses.rewardWallet, REWARD_SUPPLY);
        _mint(walletAddresses.airdropWallet, COMMUNITY_AIRDROP_SUPPLY);
    }

    function _initializeStateVariables() internal {
        totalLiquidity = 1000 * 10 ** 18; // Initial liquidity in USD
        totalPscTokensInLiquidity = 1_000_000 * 10 ** 18; // Initial PSC tokens in liquidity

        priceFeedBNB = AggregatorV3Interface(priceFeedAddresses.priceFeedBNB);
        priceFeedPSC = AggregatorV3Interface(priceFeedAddresses.priceFeedPSC);
        uniswapRouter = IUniswapV2Router02(priceFeedAddresses.uniswapRouter);

        saleEnabled = false;
        saleEnabledOnce = false;
    }

    function enableSale() external onlyOwner {
        require(!saleEnabledOnce, "Sale has already been enabled once and cannot be disabled again");
        saleEnabled = true;
        saleEnabledOnce = true;
    }

    function getLatestPriceBNB() public view returns (int) {
        (, int price,,,) = priceFeedBNB.latestRoundData();
        return price;
    }

    function getLatestPricePSC() public view returns (int) {
        (, int price,,,) = priceFeedPSC.latestRoundData();
        return price;
    }

    function buyTokens() external payable nonReentrant {
        uint256 pricePerToken = uint256(getLatestPriceBNB()) / uint256(getLatestPricePSC());
        uint256 amountBNB = msg.value;
        uint256 saltFee = (amountBNB * 15) / 1000; // 1.5%
        uint256 amountToLiquidity = amountBNB - saltFee;
        uint256 tokensToBuy = (amountToLiquidity * 10 ** 18) / pricePerToken;

        _processBuyTokens(amountBNB, saltFee, amountToLiquidity, tokensToBuy, pricePerToken);
    }

    function _processBuyTokens(
        uint256 amountBNB,
        uint256 saltFee,
        uint256 amountToLiquidity,
        uint256 tokensToBuy,
        uint256 pricePerToken
    ) internal {
        // Transfer salt fee to saltFeeWallet
        payable(walletAddresses.saltFeeWallet).transfer(saltFee);

        // Update liquidity
        totalLiquidity += amountToLiquidity;

        // Transfer tokens to buyer
        _transfer(walletAddresses.publicTradeWallet, msg.sender, tokensToBuy);

        // Add same amount of tokens to liquidity from publicTradeWallet
        _transfer(walletAddresses.publicTradeWallet, address(this), tokensToBuy);

        // Add 80% extra tokens to liquidity
        uint256 extraTokens = (tokensToBuy * 80) / 100;
        _transfer(walletAddresses.publicTradeWallet, address(this), extraTokens);

        // Update total PSC tokens in liquidity
        totalPscTokensInLiquidity = totalPscTokensInLiquidity - tokensToBuy + tokensToBuy + extraTokens;

        // Recalculate price
        pricePerToken = totalLiquidity / totalPscTokensInLiquidity;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= TOTAL_SUPPLY, "ERC20: minting would exceed total supply");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function swapTokensForBNB(uint256 tokenAmount) external onlyAuthorizedSwappers(msg.sender, tokenAmount) nonReentrant {
        // Implementation for swapping tokens for BNB
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) external onlyOwner nonReentrant {
        _approve(address(this), address(uniswapRouter), tokenAmount);

        uniswapRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function addBNBToSaltFeeWallet() external payable onlyOwner nonReentrant {
        payable(walletAddresses.saltFeeWallet).transfer(msg.value);
    }

    function withdrawBNBFromSaltFeeWallet(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(walletAddresses.saltFeeWallet).transfer(amount);
    }

    receive() external payable {}

    fallback() external payable {}
}