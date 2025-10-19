//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* 
 * @author Ayyub
 * @title OracleLib
 * @dev A library to interact with Chainlink price feeds
 * If a chainlink pricefeed is stale, it reverts.
 */

import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePriceFeed();

    uint256 private constant STALE_PRICE_THRESHOLD = 1 hours;

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (int256) {
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > STALE_PRICE_THRESHOLD) {
            revert OracleLib__StalePriceFeed();
        }
        return price;
    }
}
