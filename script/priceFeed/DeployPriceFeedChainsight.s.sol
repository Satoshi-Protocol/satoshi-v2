// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedChainsight } from "../../src/priceFeed/PriceFeedChainsight.sol";
import { IOracle } from "@chainsight-management-oracle/contracts/interfaces/IOracle.sol";
import { Script, console2 } from "forge-std/Script.sol";

//! Change when deploying
address constant CHAINSIGHT_PRICE_FEED_SOURCE_ADDRESS = 0x146447574c02deB3B802A1d4c9447CB7648aA56D;
uint256 constant MAX_TIME_THRESHOLD = 3600 + 300;
address constant SENDER_ADDRESS = 0x97089bd89A979838119D45E32B699e6C6eEad211;
bytes32 constant KEY = 0x475d5037c5f7293eb74a7e8cdec3434c759cefdf40e298e728a658dec9580afb;
uint8 constant DECIMALS = 8;

contract DeployPriceFeedChainsightScript is Script {
    PriceFeedChainsight internal priceFeedChainsight;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IOracle source = IOracle(CHAINSIGHT_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedChainsight = new PriceFeedChainsight(source, MAX_TIME_THRESHOLD, SENDER_ADDRESS, KEY, DECIMALS);
        uint256 price = priceFeedChainsight.fetchPrice();
        assert(price > 0);
        console2.log("PriceFeedChainsight deployed at:", address(priceFeedChainsight));
        console2.log("PriceFeedChainsight source address:", CHAINSIGHT_PRICE_FEED_SOURCE_ADDRESS);
        console2.log("PriceFeedChainsight maxTimeThreshold:", MAX_TIME_THRESHOLD);
        console2.log("PriceFeedChainsight sender address:", SENDER_ADDRESS);
        console2.log("PriceFeedChainsight key:");
        console2.logBytes32(KEY);
        console2.log("PriceFeedChainsight decimals:", DECIMALS);
        console2.log("PriceFeedChainsight price:", price);

        vm.stopBroadcast();
    }
}
