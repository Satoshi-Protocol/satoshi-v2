// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

import { PriceFeedRedstone } from "../../src/priceFeed/PriceFeedRedstone.sol";
import { IPriceCalculator } from "../../src/priceFeed/interfaces/IPriceCalculator.sol";

address constant REDSTONE_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0xfcd454d19f9B8806F8908e99d85b8eA17b3c7346;
address constant REDSTONE_ORACLE_ASSET_ADDRESS = 0x681202351a488040Fa4FdCc24188AfB582c9DD62;
uint8 constant REDSTONE_ORACLE_PRICE_FEED_DECIMAL = 18;
uint256 constant REDSTONE_MAX_TIME_THRESHOLD = 86_400;

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
