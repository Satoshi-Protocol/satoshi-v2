// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {PriceFeedDIAOracle} from "../../src/priceFeed/PriceFeedDIAOracle.sol";
import {IDIAOracleV2} from "../../src/priceFeed/interfaces/IDIAOracleV2.sol";
import {
    DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS,
    DIA_ORACLE_PRICE_FEED_DECIMALS,
    DIA_ORACLE_PRICE_FEED_KEY,
    DIA_MAX_TIME_THRESHOLD
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedDIAOracle internal priceFeedDIAOracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IDIAOracleV2 source = IDIAOracleV2(DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedDIAOracle = new PriceFeedDIAOracle(
            source, DIA_ORACLE_PRICE_FEED_DECIMALS, DIA_ORACLE_PRICE_FEED_KEY, DIA_MAX_TIME_THRESHOLD
        );
        assert(priceFeedDIAOracle.fetchPrice() > 0);
        console.log("PriceFeedDIAOracle deployed at:", address(priceFeedDIAOracle));

        vm.stopBroadcast();
    }
}
