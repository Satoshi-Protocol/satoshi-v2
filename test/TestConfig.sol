// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* Deploy setup */
address constant DEPLOYER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
address constant OWNER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
address constant USER_A = 0x1111111111111111111111111111111111111111;
address constant GUARDIAN = 0x2222222222222222222222222222222222222222;
string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
string constant DEBT_TOKEN_SYMBOL = "SAT";
uint32 constant SP_CLAIM_START_TIME = 0;
uint32 constant TM_CLAIM_START_TIME = 0;
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant TM_ALLOCATION = 20 * _1_MILLION;
uint256 constant SP_ALLOCATION = 10 * _1_MILLION;
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

uint8 constant ORACLE_MOCK_DECIMALS = 8;
uint256 constant ORACLE_MOCK_VERSION = 1;


uint128 constant SP_MAX_REWARD_RATE = 63419583967529168;
uint256 constant DEBT_GAS_COMPENSATION = 2e18;