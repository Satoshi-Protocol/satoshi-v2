// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_XAPP_ADDRESS = 0xEC272aF6e65C4D7857091225fa8ED300Df787CCF;

address constant ASSET_ADDRESS = 0x1217BfE6c773EEC6cc4A38b5Dc45B92292B6E189;
address constant PRICE_FEED_ADDRESS = 0x3c30848c47ad4fc38E1fB15A2926EB4d1D036364;

uint256 constant FEE_IN = 5; // 5/10000
uint256 constant FEE_OUT = 100; // 100/10000
uint256 constant DEBT_TOKEN_MINT_CAP = 1e27; // 1e9 * 1e18 = 1e27
uint256 constant DAILY_MINT_CAP = 1_000_000e18;
uint256 constant SWAP_WAITING_PERIOD = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
bool constant IS_USING_ORACLE = true;
