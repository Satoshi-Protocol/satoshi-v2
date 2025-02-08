// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_XAPP_ADDRESS = 0x95E5b977c8c33DE5b3B5D2216F1097C2017Bdf71;

address constant ASSET_ADDRESS = 0x9827431e8b77E87C9894BD50B055D6BE56bE0030;
address constant PRICE_FEED_ADDRESS = 0x2bd9891c3D0e6587996F37Ae7aC23074bd9a2f64;

uint256 constant FEE_IN = 5; // 5/10000
uint256 constant FEE_OUT = 100; // 100/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = true;
