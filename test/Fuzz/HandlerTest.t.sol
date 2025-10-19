//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Handler will narrow down the way we interact with our system under invariant testing
// This way we dont wast runs on irrelevant txns

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DecenSCEngine} from "../../src/DecenSCEngine.sol";
import {DecenSC} from "../../src/DecenSC.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockV3Aggregator} from "../Mocks/MockV3Aggregator.sol";

contract HandlerTest is Test {
    DecenSCEngine public dscEngine;
    DecenSC public dsc;

    MockERC20 public wETH;
    MockERC20 public wBTC;
    MockV3Aggregator public wETHUsdPriceFeed;
    MockV3Aggregator public wBTCUsdPriceFeed;

    // Ghost variables to track handler calls

    constructor(DecenSCEngine _dscEngine, DecenSC _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collaterals = dscEngine.getCollateralTokens();
        wETH = MockERC20(collaterals[0]); // These are to access mint function
        wBTC = MockERC20(collaterals[1]); // These are to access mint function
        wETHUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeed(address(wETH)));
        wBTCUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeed(address(wBTC)));
    }
    // Fuzzed functions to interact with the protocol

    function depositCollateral(uint256 collateralSeed, uint256 tokenAmount) public {
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);

        // Bound the amount to prevent zero and extremely large values
        tokenAmount = bound(tokenAmount, 1, type(uint96).max);

        // Mint tokens to the handler so deposit doesn't fail
        collateral.mint(address(this), tokenAmount);

        // Approve the engine to spend the tokens and receive them from the handler
        // This is necessary for the deposit to succeed
        // Because without approval, the deposit will revert
        // As the engine will try to transferFrom the handler's tokens
        collateral.approve(address(dscEngine), tokenAmount);

        // Now deposit should not revert due to insufficient balance or approval
        dscEngine.depositCollateral(address(collateral), tokenAmount);
        console.log("Deposited", tokenAmount, "of", address(collateral));
    }

    function redeemCollateral(uint256 collateralSeed, uint256 tokenAmount) public {
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed); // The MockERC20 collateral part is to access mint function

        // Get user's deposited amount to avoid trying to redeem more than deposited
        uint256 maxCollateral = dscEngine.getCollateralDeposited(address(this), address(collateral));

        if (maxCollateral == 0) {
            return; // Skip if no collateral deposited - this prevents discards
        }

        tokenAmount = bound(tokenAmount, 1, maxCollateral);

        dscEngine.redeemCollateral(address(collateral), tokenAmount);
        console.log("Redeemed", tokenAmount, "of", address(collateral));
    }

    function mintDsc(uint256 amount) public {
        // Calculate the maximum DSC that can be minted while maintaining 150% collateralization
        // Use address(this) because the handler is the one with deposited collateral
        uint256 maxDscToMint = _getMaxDscToMint(address(this));
        
        if (maxDscToMint == 0) {
            return; // Skip if no collateral deposited or already at max
        }

        // Bound the amount to between 1 and the maximum safe amount
        amount = bound(amount, 1, maxDscToMint);
        
        // Actually mint the DSC
        dscEngine.mintDSC(amount);
        console.log("Minted", amount, "DSC");
    }

    function burnDsc(uint256 amount) public {
        // Get user's DSC balance to avoid burning more than owned
        uint256 maxDsc = dsc.balanceOf(address(this));

        if (maxDsc == 0) return; // Skip if no DSC to burn

        amount = bound(amount, 1, maxDsc);

        dsc.approve(address(dscEngine), amount);
        dscEngine.burnDSC(amount);
    }

    function depositCollateralAndMintDsc(uint256 collateralSeed, uint256 collateralAmount, uint256 dscAmount) public {
        MockERC20 collateral = _getCollateralFromSeed(collateralSeed);

        collateralAmount = bound(collateralAmount, 1, type(uint96).max);
        dscAmount = bound(dscAmount, 1, type(uint96).max);

        collateral.mint(address(this), collateralAmount);
        collateral.approve(address(dscEngine), collateralAmount);

        dscEngine.depositCollateralAndMintDSC(address(collateral), collateralAmount, dscAmount);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) internal view returns (MockERC20) {
        if (collateralSeed % 2 == 0) {
            return wETH;
        } else {
            return wBTC;
        }
    }

    function _getMaxDscToMint(address user) internal view returns (uint256) {
        // Get total collateral value in USD for this handler
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine._getAccountInformation(user);

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

    // This will break our invariant test as collateral value falls significantly
    /*function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        MockV3Aggregator priceFeed;
        int256 newPrice = int256(uint256(newPrice));
        if (collateralSeed % 2 == 0) {
            wETHUsdPriceFeed.updateAnswer(newPrice);
        } else {
            wBTCUsdPriceFeed.updateAnswer(newPrice);
        }
    } */
}
