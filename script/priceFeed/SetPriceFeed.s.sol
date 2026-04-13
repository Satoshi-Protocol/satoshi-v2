// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PriceFeedAggregatorFacet } from "../../src/core/facets/PriceFeedAggregatorFacet.sol";
import { IPriceFeed } from "../../src/priceFeed/interfaces/IPriceFeed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SATOSHI_X_APP_ADDRESS = 0x2863E3D0f29E2EEC6adEFC0dF0d3171DaD542c02;
address constant TOKEN = 0x93919784C523f39CACaa98Ee0a9d96c3F32b593e;
address constant PRICE_FEED = 0xaA738260F0c7AF2976027D9e0E56E7114991a2bF;

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
