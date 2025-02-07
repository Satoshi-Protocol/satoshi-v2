// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant DEBT_TOKEN_ADDRESS = 0x78Fea795cBFcC5fFD6Fb5B845a4f53d25C283bDB;
address constant SATOSHI_XAPP_ADDRESS = 0xd6dBF24f3516844b02Ad8d7DaC9656F2EC556639;

address constant ASSET_ADDRESS = 0x4F245e278BEC589bAacF36Ba688B412D51874457;
address constant PRICE_FEED_ADDRESS = 0x4851b1F29E2A2802bb97136aEA4106992FC82f33;

uint256 constant FEE_IN = 5; // 5/10000
uint256 constant FEE_OUT = 100; // 100/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = true;
