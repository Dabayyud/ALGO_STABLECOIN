// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {MockV3Aggregator} from "test/Mocks/MockV3Aggregator.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wETHUsdPriceFeed;
        address wBTCUsdPriceFeed;
        address wETH;
        address wBTC;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8; // Chainlink price feeds use 8 decimals
    int256 public constant ETH_USD_PRICE = 4300e8; // $4300.00000000 (8 decimals)
    int256 public constant BTC_USD_PRICE = 264000e8; // $264000.00000000 (8 decimals)
    uint256 public DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public constant BTC_INITIAL_SUPPLY = 1000 * 1e8; // 1000 WBTC with 8 decimals
    uint256 public constant ETH_INITIAL_SUPPLY = 1000 * 1e18; // 1000 WETH with 18 decimals

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETHUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTCUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        // created mock price feeds with proper 8-decimal prices
        MockV3Aggregator wETHUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator wBTCUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        // Created mock tokens with name, symbol, and initial supply of 1000 ETH and 1000 BTC
        MockERC20 wETH = new MockERC20("Wrapped Ether", "WETH", ETH_INITIAL_SUPPLY);
        MockERC20 wBTC = new MockERC20("Wrapped Bitcoin", "WBTC", BTC_INITIAL_SUPPLY);

        vm.stopBroadcast();
        return NetworkConfig({
            wETHUsdPriceFeed: address(wETHUsdPriceFeed),
            wBTCUsdPriceFeed: address(wBTCUsdPriceFeed),
            wETH: address(wETH),
            wBTC: address(wBTC),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
