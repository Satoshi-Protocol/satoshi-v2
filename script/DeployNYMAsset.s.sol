// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";

import { AssetConfig, INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";
import {
    ASSET_ADDRESS,
    DAILY_MINT_CAP,
    DEBT_TOKEN_MINT_CAP,
    FEE_IN,
    FEE_OUT,
    IS_USING_ORACLE,
    MAX_PRICE,
    MIN_PRICE,
    PRICE_FEED_ADDRESS,
    SATOSHI_XAPP_ADDRESS,
    SWAP_WAITING_PERIOD
} from "./DeployNYMAssetConfig.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployNYMAssetScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiXApp;
    AssetConfig internal assetConfig;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiXApp = SATOSHI_XAPP_ADDRESS;
        assetConfig = AssetConfig({
            feeIn: FEE_IN,
            feeOut: FEE_OUT,
            debtTokenMintCap: DEBT_TOKEN_MINT_CAP,
            dailyDebtTokenMintCap: DAILY_MINT_CAP,
            debtTokenMinted: 0,
            swapWaitingPeriod: SWAP_WAITING_PERIOD,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE,
            isUsingOracle: IS_USING_ORACLE
        });
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        if (IS_USING_ORACLE) {
            IPriceFeedAggregatorFacet(satoshiXApp).setPriceFeed(IERC20(ASSET_ADDRESS), IPriceFeed(PRICE_FEED_ADDRESS));
        }

        INexusYieldManagerFacet(satoshiXApp).setAssetConfig(ASSET_ADDRESS, assetConfig);

        console.log("NYM asset deployed");
        console.log("Asset address:", ASSET_ADDRESS);
        console.log("Price feed address:", PRICE_FEED_ADDRESS);

        vm.stopBroadcast();
    }
}
