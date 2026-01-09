// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedAggregatorFacet } from "../../src/core/facets/PriceFeedAggregatorFacet.sol";
import { IPriceFeed } from "../../src/priceFeed/interfaces/IPriceFeed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SATOSHI_X_APP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
address constant TOKEN = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
address constant PRICE_FEED = 0xc96e66505fe71eB4C1b4873C6CB02C55A4189aC0;

contract SetPriceFeed is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    PriceFeedAggregatorFacet internal priceFeedAggregatorFacet;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        priceFeedAggregatorFacet = PriceFeedAggregatorFacet(SATOSHI_X_APP_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        priceFeedAggregatorFacet.setPriceFeed(IERC20(TOKEN), IPriceFeed(PRICE_FEED));

        console2.log("Set PriceFeed for Asset:", TOKEN);
        console2.log("PriceFeed Address:", PRICE_FEED);

        vm.stopBroadcast();
    }
}
