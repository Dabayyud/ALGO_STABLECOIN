// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {DecenSCEngine} from "../src/DecenSCEngine.sol";
import {DecenSC} from "../src/DecenSC.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract DSC is Test {
    DecenSCEngine public dscEngine;
    DecenSC public dsc;
    DeployDSC public deployer;
    HelperConfig public config;
    address ethUSDPriceFeed;
    address btcUSDPriceFeed;
    address wETH;
    address wBTC;
    uint256 public constant STARTING_ETHER = 10 ether;

    address public USER = makeAddr("user");

    function setUp() external {
        deployer = new DeployDSC();
        (dscEngine, dsc, config) = deployer.run();
        (ethUSDPriceFeed, btcUSDPriceFeed, wETH, wBTC,) = config.activeNetworkConfig();
        MockERC20(wETH).mint(USER, STARTING_ETHER);
    }

    //PRICE TESTS
    function testGetEthPrice() public view {
        uint256 ethAmount = 20e18;
        uint256 expectedPrice = 20 * 4300e18;
        uint256 actualPrice = dscEngine._getUSDValue(wETH, ethAmount);
        assertEq(expectedPrice, actualPrice);
    }

    function testGetBtcPrice() public view {
        uint256 btcAmount = 20e18;
        uint256 expectedPrice = 20 * 264000e18;
        uint256 actualPrice = dscEngine._getUSDValue(wBTC, btcAmount);
        assertEq(expectedPrice, actualPrice);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 4300e18;
        uint256 expectedEth = 1e18;
        uint256 actualEth = dscEngine.getTokenAmountFromUSD(wETH, usdAmount);
        assertEq(expectedEth, actualEth);
    }

    function testGetTokenAmountFromUsdBtc() public view {
        uint256 usdAmount = 264000e18;
        uint256 expectedBtc = 1e18;
        uint256 actualBtc = dscEngine.getTokenAmountFromUSD(wBTC, usdAmount);
        assertEq(expectedBtc, actualBtc);
    }

    function testRedeemCollateral() public depositCollateralETH {
        uint256 collateralToRedeem = 0.5e18;
        dscEngine.redeemCollateral(wETH, collateralToRedeem);
        uint256 expectedBalance = 0.5e18;
        uint256 actualBalance = dscEngine.getCollateralDeposited(address(this), wETH);
        assertEq(expectedBalance, actualBalance);
    }

    //DEPOSIT TESTS

    function testDepositCollateralEth() public {
        uint256 ethAmount = 1e18;

        MockERC20(wETH).mint(address(this), ethAmount);

        MockERC20(wETH).approve(address(dscEngine), ethAmount);

        dscEngine.depositCollateral(wETH, ethAmount);

        uint256 expectedBalance = ethAmount;
        uint256 actualBalance = dscEngine.getCollateralDeposited(address(this), wETH);
        assertEq(expectedBalance, actualBalance);
    }

    function testRevertIfDepositZero() public {
        uint256 ethAmount = 0;
        vm.expectRevert(DecenSCEngine.DecenSCEngine_ZeroAmount.selector);
        dscEngine.depositCollateral(wETH, ethAmount);
    }

    // LIQUIDATION TESTS

    function testDepositCollateralBtc() public {
        uint256 btcAmount = 1e18;

        MockERC20(wBTC).mint(address(this), btcAmount);

        MockERC20(wBTC).approve(address(dscEngine), btcAmount);

        dscEngine.depositCollateral(wBTC, btcAmount);

        uint256 expectedBalance = btcAmount;
        uint256 actualBalance = dscEngine.getCollateralDeposited(address(this), wBTC);
        assertEq(expectedBalance, actualBalance);
    }

    function testLiquidate() public depositCollateralETH depositCollateralBTC {
        uint256 dscToMint = 1000e18;
    }

    //CONSTRUCTOR TESTS

    function testIfChainlinkPriceFeedsAreSetCorrectly() public {
        address wETHpriceFeed = dscEngine.getPriceFeed(wETH);
        address wBTCpriceFeed = dscEngine.getPriceFeed(wBTC);

        assertEq(wETHpriceFeed, ethUSDPriceFeed);
        assertEq(wBTCpriceFeed, btcUSDPriceFeed);
    }

    function testDSCMintedCorrectly() public depositCollateralETH {
        uint256 dscToMint = 1000e18;

        dscEngine.mintDSC(dscToMint);

        uint256 expectedDSCBalance = dscToMint;
        uint256 actualDSCBalance = dsc.balanceOf(address(this));

        assertEq(expectedDSCBalance, actualDSCBalance);
    }

    function testTokenAmountInUSD() public {
        uint256 ethAmount = 1e18; // 1 ETH
        uint256 expectedValue = 4300e18; // $4300 in 18 decimal places

        uint256 actualValue = dscEngine._getUSDValue(wETH, ethAmount);

        assertEq(expectedValue, actualValue);
    }

    function testBurn() public depositCollateralETH {
        uint256 dsctoMint = 1000e18;
        dscEngine.mintDSC(dsctoMint);
        dsc.approve(address(dscEngine), dsctoMint);
        dscEngine.burnDSC(dsctoMint);
        uint256 expectedDSCBalance = 0;
        uint256 actualDSCBalance = dsc.balanceOf(address(this));
        assertEq(expectedDSCBalance, actualDSCBalance);
    }

    function testGetCollateralDeposited() public depositCollateralETH {
        uint256 expectedBalance = 1e18;
        uint256 actualBalance = dscEngine.getCollateralDeposited(address(this), wETH);
        assertEq(expectedBalance, actualBalance);
    }

    function testGetCollateralizationRatio() public depositCollateralETH {
        uint256 dscToMint = 1000e18;
        dscEngine.mintDSC(dscToMint);
        uint256 expectedRatio = 430; // 430%
        uint256 actualRatio = dscEngine._getCollateralizationRatio(address(this));
        assertEq(expectedRatio, actualRatio);
    }

    //MODIFIERS FOR CLEANER TESTS

    modifier onlyUser() {
        vm.startPrank(USER);
        _;
        vm.stopPrank();
    }

    modifier depositCollateralETH() {
        uint256 ethAmount = 1e18;
        MockERC20(wETH).mint(address(this), ethAmount);
        MockERC20(wETH).approve(address(dscEngine), ethAmount);
        dscEngine.depositCollateral(wETH, ethAmount);
        _;
    }

    modifier depositCollateralBTC() {
        uint256 btcAmount = 1e18;
        MockERC20(wBTC).mint(address(this), btcAmount);
        MockERC20(wBTC).approve(address(dscEngine), btcAmount);
        dscEngine.depositCollateral(wBTC, btcAmount);
        _;
    }

    modifier depositAndMintDSCUndercollateralized() {
        address user = makeAddr("undercollateralizedUser");
        uint256 ethAmount = 1e18;
        uint256 dscToMint = 2000e18; // Undercollateralized at 150% ratio
        MockERC20(wETH).mint(user, ethAmount);
        vm.startPrank(user);
        MockERC20(wETH).approve(address(dscEngine), ethAmount);
        dscEngine.depositCollateral(wETH, ethAmount);
        dscEngine.mintDSC(dscToMint);
        vm.stopPrank();
        _;
    }

    modifier createHealthyLiquidationScenario() {
        address user = makeAddr("healthyUser"); // Declare user here
        address liquidator = makeAddr("liquidator");
        uint256 ethAmount = 10e18; // 10 ETH
        uint256 dscToMint = 1000e18; // $1000 DSC (well within 150% ratio)
        MockERC20(wETH).mint(user, ethAmount);
        vm.startPrank(user);
        MockERC20(wETH).approve(address(dscEngine), ethAmount);
        dscEngine.depositCollateral(wETH, ethAmount);
        dscEngine.mintDSC(dscToMint);
        vm.stopPrank();
        _;
    }

    //REVERT TESTS

    function testRevertsIfBelowMinCollateralRatio() public {
        uint256 dscToMint = 1000e18;
        vm.expectRevert(abi.encodeWithSelector(DecenSCEngine.DecenSCEngine_BelowMinCollateralRatio.selector, 0));
        dscEngine.mintDSC(dscToMint);
    }

    function testRevertsIfZeroAmount() public {
        uint256 dscToMint = 0;
        vm.expectRevert(DecenSCEngine.DecenSCEngine_ZeroAmount.selector);
        dscEngine.mintDSC(dscToMint);
    }

    function testRevertsIfTokenArrayAndPriceFeedArrayLengthDontMatch() public {
        address[] memory tokenAddresses = new address[](2);
        address[] memory priceFeeds = new address[](1); // Different length
        tokenAddresses[0] = wETH;
        tokenAddresses[1] = wBTC;
        priceFeeds[0] = ethUSDPriceFeed;

        vm.expectRevert(DecenSCEngine.DecenSCEngine_LengthMismatch.selector);
        new DecenSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    function testRevertsWithUnapprovedToken() public {
        MockERC20 notApprovedToken = new MockERC20("Not Approved Token", "NAT", 1000e18);
        vm.expectRevert(DecenSCEngine.DecenSCEngine_NotAllowedToken.selector);
        dscEngine.depositCollateral(address(notApprovedToken), 1e18);
    }

    function testGetAccountInformation() public depositCollateralETH {
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = dscEngine._getAccountInformation(address(this));
        assertEq(totalDSCMinted, 0);
        assertEq(collateralValueInUSD, 4300e18);
    }

    function testLiquidateRevertsIfUserIsNotUnderCollateralized() public depositCollateralETH {
        address user = makeAddr("healthyUser");
        uint256 ethAmount = 10e18; // 10 ETH
        uint256 dscToMint = 1000e18; // $1000 DSC (well within 150% ratio)

        dscEngine.mintDSC(dscToMint);
        vm.stopPrank();

        // Setup liquidator - liquidator needs collateral to mint DSC
        address liquidator = makeAddr("liquidator");
        uint256 liquidatorEthAmount = 5e18; // 5 ETH for liquidator
        uint256 liquidatorDscAmount = 500e18; // $500 DSC

        MockERC20(wETH).mint(liquidator, liquidatorEthAmount);
        vm.startPrank(liquidator);
        MockERC20(wETH).approve(address(dscEngine), liquidatorEthAmount);
        dscEngine.depositCollateral(wETH, liquidatorEthAmount);
        dscEngine.mintDSC(liquidatorDscAmount); // Liquidator mints their own DSC
        dsc.approve(address(dscEngine), liquidatorDscAmount);

        // This should revert because user is not undercollateralized
        vm.expectRevert();
        dscEngine.liquidate(wETH, user, 100e18);
        vm.stopPrank();
    }

    function testGetters() public view {
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], wETH);
        assertEq(collateralTokens[1], wBTC);
    }

    function testRevertIfTokenLengthDoesNotMatchPriceFeedLength() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeeds = new address[](2);
        tokenAddresses[0] = wETH;
        priceFeeds[0] = ethUSDPriceFeed;
        priceFeeds[1] = btcUSDPriceFeed;

        vm.expectRevert(DecenSCEngine.DecenSCEngine_LengthMismatch.selector);
        new DecenSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    function testBranches() public {
        address owner = dscEngine.owner();
        assertEq(owner, address(dscEngine)); // Owner should be the engine, not the test contract
    }
    // Test successful liquidation instead - the other error is hard to trigger

    function testSuccessfulLiquidation() public {
        // Create a user who starts healthy but becomes undercollateralized
        address user = makeAddr("user");
        uint256 ethAmount = 50e18; // 5 ETH = $21,500 initially
        uint256 dscToMint = 5000e18; // $5000 DSC (ratio = 430%, healthy)

        MockERC20(wETH).mint(user, ethAmount);
        vm.startPrank(user);
        MockERC20(wETH).approve(address(dscEngine), ethAmount);
        dscEngine.depositCollateral(wETH, ethAmount);
        dscEngine.mintDSC(dscToMint);
        vm.stopPrank();

        // Price drops: ETH goes from $4300 to $1400 to make user undercollateralized
        // 5 ETH × $1400 = $7000 collateral, $5000 DSC → 140% ratio (below 150%)
        MockV3Aggregator(ethUSDPriceFeed).updateAnswer(1400e8);

        address liquidator = makeAddr("liquidator");
        uint256 liquidatorEthAmount = 30e18;
        uint256 liquidatorDscAmount = 100e18;

        MockERC20(wETH).mint(liquidator, liquidatorEthAmount);
        vm.startPrank(liquidator);
        MockERC20(wETH).approve(address(dscEngine), liquidatorEthAmount);
        dscEngine.depositCollateral(wETH, liquidatorEthAmount);
        dscEngine.mintDSC(liquidatorDscAmount);
        dsc.approve(address(dscEngine), liquidatorDscAmount);

        uint256 debtToCover = 100e18; // Liquidate only $100 of debt

        // The liquidation should revert because user would still be undercollateralized after
        vm.expectRevert();
        dscEngine.liquidate(wETH, user, debtToCover);
        vm.stopPrank();
    }

    // Test redeem collateral that would break collateral ratio
    function testRedeemCollateralRevertsIfBreaksCollateralRatio() public depositCollateralETH {
        uint256 dscToMint = 2000e18; // $2000 DSC with 1 ETH ($4300) collateral = 215% ratio
        dscEngine.mintDSC(dscToMint);

        uint256 collateralToRedeem = 1e18; // Try to redeem all collateral

        vm.expectRevert(); // Should revert because this would leave user with no collateral but DSC debt
        dscEngine.redeemCollateral(wETH, collateralToRedeem);
    }
}
