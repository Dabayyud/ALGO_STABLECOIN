// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {DecenSCEngine} from "../src/DecenSCEngine.sol";
import {DecenSC} from "../src/DecenSC.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeeds;

    function run() external returns (DecenSCEngine, DecenSC, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wETHUsdPriceFeed, address wBTCUsdPriceFeed, address wETH, address wBTC, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses.push(wETH);
        tokenAddresses.push(wBTC);
        priceFeeds.push(wETHUsdPriceFeed);
        priceFeeds.push(wBTCUsdPriceFeed);

        vm.startBroadcast(deployerKey);
        DecenSC dsc = new DecenSC();
        DecenSCEngine dscEngine = new DecenSCEngine(tokenAddresses, priceFeeds, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dscEngine, dsc, config);
    }
}
