// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISupraSValueFeed} from "../../src/priceFeed/interfaces/ISupraSValueFeed.sol";
import {PriceFeedSupraOracle} from "../../src/priceFeed/PriceFeedSupraOracle.sol";
import {ISupraOraclePull} from "../../src/priceFeed/interfaces/ISupraOraclePull.sol";

import {
    SUPRA_MAX_TIME_THRESHOLD,
    SUPRA_ORACLE_PAIR_INDEX,
    SUPRA_ORACLE_PRICE_FEED_DECIMAL,
    SUPRA_ORACLE_PRICE_FEED_SOURCE_ADDRESS,
    SUPRA_ORACLE_PRICE_FEED_PULL_SOURCE_ADDRESS
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedSupraScript is Script {
    PriceFeedSupraOracle internal priceFeedSupraOracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        ISupraSValueFeed source = ISupraSValueFeed(SUPRA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        ISupraOraclePull pullSource = ISupraOraclePull(SUPRA_ORACLE_PRICE_FEED_PULL_SOURCE_ADDRESS);
        priceFeedSupraOracle = new PriceFeedSupraOracle(
            source, pullSource, SUPRA_ORACLE_PRICE_FEED_DECIMAL, SUPRA_MAX_TIME_THRESHOLD, SUPRA_ORACLE_PAIR_INDEX
        );
        assert(priceFeedSupraOracle.fetchPrice() > 0);
        console.log("PriceFeedSupraOracle deployed at:", address(priceFeedSupraOracle));

        vm.stopBroadcast();
    }
}
