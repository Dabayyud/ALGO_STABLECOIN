/* //SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// This folder will hold our property based tests

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DecenSCEngine} from "../../src/DecenSCEngine.sol";
import {DecenSC} from "../../src/DecenSC.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract InvariantTest is StdInvariant, Test {
    DecenSCEngine dscEngine;
    DeployDSC deployer;
    DecenSC dsc;
    HelperConfig helperConfig;
    address wETH;
    address wBTC;

    function setUp() external {
        deployer = new DeployDSC();
        (dscEngine, dsc, helperConfig) = deployer.run();
        (,,wETH, wBTC,) = helperConfig.activeNetworkConfig();
        targetContract(address(dscEngine)); // Tells foundry to go wild on this contract
    }

    function invariant_engineMustAlwaysBeOverCollateralized() public view {
        // Get total DSC minted from the engine
        uint256 totalDscMinted = dsc.totalSupply();
        // Get total amount of weth and wbtc deposited in the engine through the IERC20 interface
        uint256 totalwethDeposited = IERC20(wETH).balanceOf(address(dscEngine));
        uint256 totalwbtcDeposited = IERC20(wBTC).balanceOf(address(dscEngine));

        // Use the engine's getUsdValue function to calculate total collateral value in USD
        uint256 totalCollateralValueInUsd = dscEngine._getUSDValue(wETH, totalwethDeposited) +
            dscEngine._getUSDValue(wBTC, totalwbtcDeposited);

        console.log("Total DSC Minted:", totalDscMinted);
        console.log("Total Collateral Value in USD:", totalCollateralValueInUsd);

        // Assert that the total collateral value is always greater than or equal to total DSC minted
        assert(totalCollateralValueInUsd >= totalDscMinted);
    }
}
*/
