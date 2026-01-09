// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_XAPP_ADDRESS = 0xB4d4793a1CD57b6EceBADf6FcbE5aEd03e8e93eC;

address constant ASSET_ADDRESS = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;
address constant PRICE_FEED_ADDRESS = 0x73c24ffde0648A8669BE59112d656222aa0873bb;

uint256 constant FEE_IN = 5; // 5/10000
uint256 constant FEE_OUT = 100; // 100/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = true;
