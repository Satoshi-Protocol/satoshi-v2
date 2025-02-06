// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedChainlink } from "../../src/priceFeed/PriceFeedChainlink.sol";
import { AggregatorV3Interface } from "../../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0 } from "./DeployPriceFeedConfig.sol";
import { Script, console } from "forge-std/Script.sol";

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

        AggregatorV3Interface source = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0);
        priceFeedChainlink = new PriceFeedChainlink(source);
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
