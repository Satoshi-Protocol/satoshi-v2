// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant OWNER = 0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47;
address constant GUARDIAN = 0x8B483EBb3abfc25AEC2e88222Bf79D6d0fc44B0B;
address constant FEE_RECEIVER = 0x4D8a2eae0e8a3e0fDeb1f9270eD5F850BFd4EcBC;

address constant WETH_ADDRESS = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;

address constant LZ_ENDPOINT = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin V2";
string constant DEBT_TOKEN_SYMBOL = "satUSD";

uint256 constant MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant DEBT_GAS_COMPENSATION = 2e18; // 2 SAT

uint32 constant SP_CLAIM_START_TIME = 4_294_967_295; // max uint32
uint256 constant SP_ALLOCATION = 0; // 0 initial allocation
uint128 constant SP_REWARD_RATE = 0; // 0 initial reward rate
