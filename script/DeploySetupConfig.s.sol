// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant OWNER = 0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47;
address constant GUARDIAN = 0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47;
address constant FEE_RECEIVER = 0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47;

address constant WETH_ADDRESS = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

address constant LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin V2";
string constant DEBT_TOKEN_SYMBOL = "satUSD";

uint256 constant MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant DEBT_GAS_COMPENSATION = 2e18; // 2 SAT

uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
uint256 constant SP_ALLOCATION = 0; // 0 initial allocation
uint256 constant SP_REWARD_RATE = 0; // 0 initial reward rate
