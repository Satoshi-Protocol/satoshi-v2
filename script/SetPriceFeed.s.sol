// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

address constant SATOSHI_XAPP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
address constant ASSET_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
address constant PRICE_FEED_ADDRESS = 0x0298FDAF781AD0804d2fad2f54D4bD2CF3787F4a;

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
