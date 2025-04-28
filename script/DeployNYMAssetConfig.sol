// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_XAPP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;

address constant ASSET_ADDRESS = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
address constant PRICE_FEED_ADDRESS = 0x23e727E4919eB9f11200197014ab96d03008Ccff;

uint256 constant FEE_IN = 5; // 5/10000
uint256 constant FEE_OUT = 100; // 100/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = true;
