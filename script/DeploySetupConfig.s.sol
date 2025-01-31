// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant OWNER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
address constant GUARDIAN = 0x604226C8242617c73A344035B7907cd93e284480;
address constant FEE_RECEIVER = 0xBc3Cadd627532C79593EA7238eD9C3E96e2e8A7f;

address constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

address constant LZ_ENDPOINT = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin V2";
string constant DEBT_TOKEN_SYMBOL = "satUSD";

uint256 constant MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant DEBT_GAS_COMPENSATION = 2e18; // 2 SAT

uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
uint256 constant SP_ALLOCATION = 0; // 0 initial allocation
uint256 constant SP_REWARD_RATE = 0; // 0 initial reward rate
