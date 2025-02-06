// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IWstBTCPartial, PriceFeedWstBTCWithDIAOracle } from "../../src/priceFeed/PriceFeedWstBTCWithDIAOracle.sol";
import { IDIAOracleV2 } from "../../src/priceFeed/interfaces/IDIAOracleV2.sol";
import {
    DIA_MAX_TIME_THRESHOLD,
    DIA_ORACLE_PRICE_FEED_DECIMALS,
    DIA_ORACLE_PRICE_FEED_KEY,
    DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS,
    WSTBTC_ADDRESS
} from "./DeployPriceFeedConfig.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployPriceFeedWSTBTCScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    PriceFeedWstBTCWithDIAOracle internal priceFeedWstBTCWithDIAOracle;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IDIAOracleV2 source = IDIAOracleV2(DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        IWstBTCPartial wstBTC = IWstBTCPartial(WSTBTC_ADDRESS);
        priceFeedWstBTCWithDIAOracle = new PriceFeedWstBTCWithDIAOracle(
            source, DIA_ORACLE_PRICE_FEED_DECIMALS, DIA_ORACLE_PRICE_FEED_KEY, DIA_MAX_TIME_THRESHOLD, wstBTC
        );
        assert(priceFeedWstBTCWithDIAOracle.fetchPrice() > 0);
        console.log("wstbtc price", priceFeedWstBTCWithDIAOracle.fetchPrice());
        console.log("PriceFeedWstBTCWithDIAOracle deployed at:", address(priceFeedWstBTCWithDIAOracle));

        vm.stopBroadcast();
    }
}
