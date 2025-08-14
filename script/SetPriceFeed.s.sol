// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

address constant SATOSHI_XAPP_ADDRESS = 0xEC272aF6e65C4D7857091225fa8ED300Df787CCF;
address constant ASSET_ADDRESS = 0xCC0966D8418d412c599A6421b760a847eB169A8c;
address constant PRICE_FEED_ADDRESS = 0x690070E052cae6615aD404eC7b288598eb01d8A5;

contract SetPriceFeedScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiXApp;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiXApp = SATOSHI_XAPP_ADDRESS;
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        IPriceFeedAggregatorFacet(satoshiXApp).setPriceFeed(IERC20(ASSET_ADDRESS), IPriceFeed(PRICE_FEED_ADDRESS));

        console.log("Set price feed");
        console.log("Asset address:", ASSET_ADDRESS);
        console.log("Price feed address:", PRICE_FEED_ADDRESS);

        vm.stopBroadcast();
    }
}
