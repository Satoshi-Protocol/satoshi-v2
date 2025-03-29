// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedChainlink } from "../../src/priceFeed/PriceFeedChainlink.sol";
import { AggregatorV3Interface } from "../../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { Script, console2 } from "forge-std/Script.sol";

//! Change when deploying
address constant CHAINLINK_PRICE_FEED_SOURCE_ADDRESS = 0x31a36CdF4465ba61ce78F5CDbA26FDF8ec361803;
uint256 constant CHAINLINK_MAX_TIME_THRESHOLD = 21600 + 300;

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedChainlink internal priceFeedChainlink;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        AggregatorV3Interface source = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlink(source, CHAINLINK_MAX_TIME_THRESHOLD);
        uint256 price = priceFeedChainlink.fetchPrice();
        assert(price > 0);
        console2.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));
        console2.log("PriceFeedChainlink source address:", CHAINLINK_PRICE_FEED_SOURCE_ADDRESS);
        console2.log("PriceFeedChainlink max time threshold:", CHAINLINK_MAX_TIME_THRESHOLD);
        console2.log("PriceFeedChainlink price:", price);

        vm.stopBroadcast();
    }
}
