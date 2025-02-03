// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* LayerZero Settings */
/* Ref: https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts */
address constant ETH_HOLESKY_LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
uint32 constant ETH_HOLESKY_LZ_EID = 40217;

address constant ARB_SEPOLIA_LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
uint32 constant ARB_SEPOLIA_LZ_EID = 40231;

address constant OP_SEPOLIA_LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
uint32 constant OP_SEPOLIA_LZ_EID = 40232;

address constant BASE_SEPOLIA_LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
uint32 constant BASE_SEPOLIA_LZ_EID = 40245;

address constant CORE_SEPOLIA_LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
uint32 constant CORE_SEPOLIA_LZ_EID = 40153;

/* Deploy setup */
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
uint256 constant LIQUIDATION_FEE = 200; //  (0.2%)
uint256 constant CCR = 1500000000000000000; // 150%
