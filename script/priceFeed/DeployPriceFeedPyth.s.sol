// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedPythOracle } from "../../src/priceFeed/PriceFeedPythOracle.sol";

import {
    PYTH_MAX_TIME_THRESHOLD,
    PYTH_ORACLE_PRICEID,
    PYTH_ORACLE_PRICE_FEED_DECIMAL,
    PYTH_ORACLE_PRICE_FEED_SOURCE_ADDRESS
} from "./DeployPriceFeedConfig.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedPythOracle internal priceFeedPythOracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IPyth source = IPyth(PYTH_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedPythOracle = new PriceFeedPythOracle(
            source, PYTH_ORACLE_PRICE_FEED_DECIMAL, PYTH_ORACLE_PRICEID, PYTH_MAX_TIME_THRESHOLD
        );
        assert(priceFeedPythOracle.fetchPrice() > 0);
        console.log("priceFeedPyth deployed at:", address(priceFeedPythOracle));

        vm.stopBroadcast();
    }
}
