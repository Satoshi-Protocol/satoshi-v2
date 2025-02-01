// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {PriceFeedChainlinkExchangeRate} from "../../src/priceFeed/PriceFeedChainlinkExchangeRate.sol";
import {AggregatorV3Interface} from "../../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import {SourceConfig} from "../../src/priceFeed/interfaces/IPriceFeed.sol";
import {
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0,
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1,
    CHAINLINK_MAX_TIME_THRESHOLD_0,
    CHAINLINK_MAX_TIME_THRESHOLD_1
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkExchangeRateScript is Script {
    PriceFeedChainlinkExchangeRate internal priceFeedChainlink;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        SourceConfig[] memory sources = new SourceConfig[](2);
        sources[0] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_0,
            weight: 0
        });
        sources[1] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_1,
            weight: 0
        });

        priceFeedChainlink = new PriceFeedChainlinkExchangeRate( sources);
        (, int256 answer,,,) = priceFeedChainlink.latestRoundData();
        assert(answer > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
