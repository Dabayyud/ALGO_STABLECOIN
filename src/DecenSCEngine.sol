// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {DecenSC} from "./DecenSC.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../test/OracleLib.sol";

/* 
 * @author Ayyub
 * @title DecenSCEngine
 * @dev A decentralized smart contract engine template
 *Collateral: wETH, wBTC
 *Relative Stability: Low Volatility
 *This contract will be the engine of the DSC. This contract is an implementation of the ERC20.
 * It will be used to mint and burn the DSC.
 * It will be used to manage the collateral (always overcollateralized).
 * It will incentivize users to maintain the collateralization ratio.
 * It will be pegged to the USD though chainlink oracles.
 * This engine closely resembles that of the MAKERDAO system.
 */

contract DecenSCEngine is ReentrancyGuard {
    //ERRORS
    error DecenSCEngine_ZeroAmount();
    error DecenSCEngine_NotAllowedToken();
    error DecenSCEngine_LengthMismatch();
    error DecenSCEngine_TransferFailed();
    error DecenSCEngine_BelowMinCollateralRatio(uint256 collateralizationRatio);
    error DecenSCEngine_CollateralizationRatioNotImproved();

    //TYPE DECLARATIONS
    using OracleLib for AggregatorV3Interface;

    //STATE VARIABLES
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // To bring the 8 decimal places from the price feed to 18 decimal places
    uint256 private constant PRECISION = 1e18; // To bring the 8 decimal places from the price feed to 18 decimal places

    mapping(address token => address priceFeed) private s_PriceFeedMapping; // token address -> price feed address
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposited; // user address -> token address -> amount deposited
    mapping(address user => uint256 amountDSCminted) private s_DSCMinted; // user address -> DSC minted

    DecenSC private immutable i_DSC;
    uint256 private constant MIN_COLLATERAL_RATIO = 150; // 150%
    uint256 private constant LIQUIDATION_CONSTANT = 100; // 100%
    uint256 private constant LIQUIDATION_BONUS = 15; // 15%
    address[] private s_CollateralTokens; // List of all collateral tokens accepted

    //EVENTS
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralWithdrawn(
        address indexed RedeemedFrom, address indexed RedeemedTo, address indexed token, uint256 amount
    );

    //MODIFIERS
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DecenSCEngine_ZeroAmount();
        }
        _;
    }

    modifier allowedToken(address token) {
        if (s_PriceFeedMapping[token] == address(0)) {
            revert DecenSCEngine_NotAllowedToken();
        }
        _;
    }

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address DecenSCAddress // Pass the input parameters upon deployment
    ) {
        // USD price feeds;
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DecenSCEngine_LengthMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_PriceFeedMapping[tokenAddresses[i]] = priceFeedAddresses[i];
            s_CollateralTokens.push(tokenAddresses[i]); // Keep track of accepted collateral tokens
        }
        i_DSC = DecenSC(DecenSCAddress);
    }
    // Instead of hardocoding the tokens and price feeds, we can pass them as parameters to the constructor.
    // This will make the contract more flexible and reusable on other networks.

    //EXTERNAL FUNCTIONS
    //The function allows users to deposit collateral and mint DSC in a single transaction.

    function depositCollateralAndMintDSC(address collateralTokenAddress, uint256 tokenAmount, uint256 dscAmount)
        external
    {
        depositCollateral(collateralTokenAddress, tokenAmount);
        mintDSC(dscAmount);
    }

    /* Note: Follows CEI pattern (Checks-Effects-Interactions)
     * @param collateralTokenAddress The address of the collateral token
     * @param tokenAmount The amount of collateral to deposit
     */

    function depositCollateral(address collateralTokenAddress, uint256 tokenAmount)
        public
        moreThanZero(tokenAmount)
        allowedToken(collateralTokenAddress)
        nonReentrant
    {
        //CEI (checks-effects-interactions) pattern
        s_CollateralDeposited[msg.sender][collateralTokenAddress] += tokenAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, tokenAmount);
        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), tokenAmount);
        if (!success) {
            revert DecenSCEngine_TransferFailed();
        }
    }

    function redeemCollateralForDSC(address collateralTokenAddress, uint256 amountCollateral, uint256 amountDSCburn)
        external
    {
        burnDSC(amountDSCburn);
        redeemCollateral(collateralTokenAddress, amountCollateral);
    }

    //In order to redeem collateral, users must burn an equivalent amount of DSC,
    //Collateralization ratio must be >1,
    function redeemCollateral(address collateralTokenAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        allowedToken(collateralTokenAddress)
        nonReentrant
    {
        _redeemCollateral(collateralTokenAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfNotEnoughCollateral(msg.sender);
    }

    /*
     * 1. Check collateralization ratio; Price Feeds, values etc.
     * 2. If the ratio is above the threshold, allow minting
     * 3. If the ratio is below the threshold, revert the transaction
     * @notice follows CEI pattern (Checks-Effects-Interactions)
     * 
    */

    function burnDSC(uint256 amountDSCtoBurn) public moreThanZero(amountDSCtoBurn) nonReentrant {
        _burnDSC(amountDSCtoBurn, msg.sender, msg.sender);
        _revertIfNotEnoughCollateral(msg.sender);
    }

    //low level internal function dont call this function directly outside of this contract
    function _burnDSC(uint256 amountDSCtoBurn, address BehalfOf, address DSCFrom) internal {
        bool success = i_DSC.transferFrom(DSCFrom, address(this), amountDSCtoBurn);
        if (!success) {
            revert DecenSCEngine_TransferFailed();
        }
        s_DSCMinted[BehalfOf] -= amountDSCtoBurn;
        _revertIfNotEnoughCollateral(BehalfOf); // This internal function can be used in liquidation context
        i_DSC.burn(amountDSCtoBurn);
    }

    // If someone is almost below the minimum collateralization ratio, they can choose to liquidate a portion of their position
    // to bring their collateralization ratio back above the minimum
    // liquidator takes the collateral at a discount and burns the DSC

    function liquidate(address collateral, address user, uint256 Debt) external {
        // Check if the user is below the minimum collateralization ratio
        uint256 userCollateralizationRatio = _getCollateralizationRatio(user);
        if (userCollateralizationRatio >= MIN_COLLATERAL_RATIO) {
            revert DecenSCEngine_BelowMinCollateralRatio(userCollateralizationRatio);
        }
        uint256 tokenAmountFromUSD = getTokenAmountFromUSD(collateral, Debt);
        // Give the liquidator a 15% bonus
        uint256 bonusCollateral = (tokenAmountFromUSD * LIQUIDATION_BONUS) / 100;
        uint256 totalCollateralToRedeem = tokenAmountFromUSD + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDSC(Debt, user, msg.sender);

        uint256 newCollateralizationRatio = _getCollateralizationRatio(user);
        if (newCollateralizationRatio < MIN_COLLATERAL_RATIO && s_DSCMinted[user] > 0) {
            revert DecenSCEngine_CollateralizationRatioNotImproved();
        }
        _revertIfNotEnoughCollateral(user);
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeedMapping[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 tokenPrice = uint256(price) * ADDITIONAL_FEED_PRECISION;
        return (usdAmount * PRECISION) / tokenPrice;
    }

    //low level internal function dont call this function directly outside of this contract
    function _redeemCollateral(address collateralTokenAddress, uint256 amountCollateral, address from, address to)
        internal
    {
        s_CollateralDeposited[from][collateralTokenAddress] -= amountCollateral;
        emit CollateralWithdrawn(from, to, collateralTokenAddress, amountCollateral);
        _revertIfNotEnoughCollateral(from);
        bool success = IERC20(collateralTokenAddress).transfer(to, amountCollateral);
        if (!success) {
            //This internal function can be used in liquidation context
            revert DecenSCEngine_TransferFailed();
        }
    }

    function mintDSC(uint256 amountDSCtoMint) public moreThanZero(amountDSCtoMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCtoMint;
        _revertIfNotEnoughCollateral(msg.sender);
        bool minted = i_DSC.mint(msg.sender, amountDSCtoMint);
        if (!minted) {
            revert DecenSCEngine_TransferFailed();
        }
    } // only when users believe DSC is overcollateralized

    // Returns how close to liquidation a user is
    // If user is below 150%, they can be liquidated
    function _getCollateralizationRatio(address user) public view returns (uint256) {
        // total DSC minted
        // total collateral value
        // collateralization ratio = (total collateral value * 100) / total DSC minted
        (uint256 totalDSCMinted, uint256 totalCollateralValueInUSD) = _getAccountInformation(user);
        if (totalDSCMinted == 0) return type(uint256).max;

        // Calculate actual collateralization ratio as percentage
        // Both values are in 18 decimals, so we get percentage directly
        return (totalCollateralValueInUSD * 100) / totalDSCMinted;
        // example of calculating collateralization ratio:
        // totalDSCMinted = $100 (100e18)
        // totalCollateralValueInUSD = $300 (300e18)
        // collateralization ratio = (300e18 * 100) / 100e18 = 300 (represents 300%)
    }

    function _getAccountInformation(address user) public view returns (uint256, uint256) {
        uint256 totalDSCMinted = s_DSCMinted[user];
        uint256 totalCollateralValueInUSD = _getAccountCollateralValue(user);
        return (totalDSCMinted, totalCollateralValueInUSD);
    }

    function _getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUSD) {
        // loop through each collateral token, get the amount deposited, get the price from the price feed, calculate the USD value
        // sum the USD value of each collateral token
        for (uint256 i = 0; i < s_CollateralTokens.length; i++) {
            // Loop through each collateral token to ensure all are counted
            address token = s_CollateralTokens[i];
            uint256 amount = s_CollateralDeposited[user][token];
            totalCollateralValueInUSD += _getUSDValue(token, amount);
        }
    }

    function _getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeedMapping[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // price returned with 8 decimals just like how ETH/USD or BTC/USD price feeds work
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // Adjusting to 18 decimals for consistency
    }

    function _revertIfNotEnoughCollateral(address user) internal view {
        uint256 collateralizationRatio = _getCollateralizationRatio(user);
        if (collateralizationRatio < MIN_COLLATERAL_RATIO) {
            revert DecenSCEngine_BelowMinCollateralRatio(collateralizationRatio);
        }
    }

    function _getMaxDscToMint() internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(address(this));

        if (collateralValueInUsd == 0) {
            return 0; // No collateral deposited
        }

        // Calculate max DSC that can be minted while maintaining 150% collateralization
        // Formula: maxDsc = (collateralValue * 100) / 150
        uint256 maxDscAllowed = (collateralValueInUsd * 100) / 150;

        // Subtract already minted DSC to get remaining mintable amount
        if (maxDscAllowed <= totalDscMinted) {
            return 0; // Already at or above maximum
        }

        return maxDscAllowed - totalDscMinted;
    }

    function getMaxDscToMint() external view returns (uint256) {
        return _getMaxDscToMint();
    }

    //GETTER FUNCTIONS FOR TESTING PURPOSES

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_PriceFeedMapping[token];
    }

    function getDSCAddress() external view returns (address) {
        return address(i_DSC);
    }

    function getPriceFeed(address token) external view returns (address) {
        return s_PriceFeedMapping[token];
    }

    function getCollateralDeposited(address user, address token) external view returns (uint256) {
        return s_CollateralDeposited[user][token];
    }

    function getDSCMinted(address user) external view returns (uint256) {
        return s_DSCMinted[user];
    }

    function getMinCollateralRatio() external pure returns (uint256) {
        return MIN_COLLATERAL_RATIO;
    }

    function getTokenPrice(address token) external view returns (uint256) {
        return _getUSDValue(token, 1e18);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_CollateralTokens;
    }

    function owner() external view returns (address) {
        return i_DSC.owner();
    }
}
