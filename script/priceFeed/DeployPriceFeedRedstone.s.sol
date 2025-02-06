// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

import { PriceFeedRedstone } from "../../src/priceFeed/PriceFeedRedstone.sol";
import { IPriceCalculator } from "../../src/priceFeed/interfaces/IPriceCalculator.sol";
import {
    REDSTONE_MAX_TIME_THRESHOLD,
    REDSTONE_ORACLE_ASSET_ADDRESS,
    REDSTONE_ORACLE_PRICE_FEED_DECIMAL,
    REDSTONE_ORACLE_PRICE_FEED_SOURCE_ADDRESS
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedRedstoneScript is Script {
    PriceFeedRedstone internal priceFeedRedstoneOracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IPriceCalculator source = IPriceCalculator(REDSTONE_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedRedstoneOracle = new PriceFeedRedstone(
            source, REDSTONE_ORACLE_ASSET_ADDRESS, REDSTONE_ORACLE_PRICE_FEED_DECIMAL, REDSTONE_MAX_TIME_THRESHOLD
        );
        assert(priceFeedRedstoneOracle.fetchPrice() > 0);
        console.log("priceFeedRedstone deployed at:", address(priceFeedRedstoneOracle));

        vm.stopBroadcast();
    }
}
