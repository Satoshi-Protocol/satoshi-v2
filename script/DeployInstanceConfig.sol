// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_X_APP_ADDRESS = 0x2863E3D0f29E2EEC6adEFC0dF0d3171DaD542c02;
address constant REWARD_MANAGER_ADDRESS = 0xba50dDac6B2F5482cA064EFAc621E0C7c0f6A783;
address constant VAULT_MANAGER_ADDRESS = 0x03d9C4E4BC5D3678A9076caC50dB0251D8676872;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x2dF10F991BFA70eeb3f68E1A7c7953943157A56b;
address constant COLLATERAL_ADDRESS = 0x93919784C523f39CACaa98Ee0a9d96c3F32b593e;
uint256 constant MCR = 160 * 1e16; //  110 * 1e16 -> 110%

uint256 constant MINUTE_DECAY_FACTOR = 999_037_758_833_783_500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (0%)
uint256 constant MAX_DEBT = 1e18 * 100_000; //  (1 billion)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 0; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4_294_967_295; // max uint32

// farming parameters
uint256 constant RETAIN_PERCENTAGE = 0; // 10_000 -> 100%
uint256 constant REFILL_PERCENTAGE = 0; // 10_000 -> 100%
