// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_X_APP_ADDRESS = 0xB4d4793a1CD57b6EceBADf6FcbE5aEd03e8e93eC;
address constant REWARD_MANAGER_ADDRESS = 0xEF462c1De03eA378b76a36Bb02c7Ab22801e68c3;
address constant VAULT_MANAGER_ADDRESS = 0xC689B47A95a8a4Ef006F29DDD111E5d466bfAA48;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xf64AF34e614955760C331Fc055b25Bcf9Dc1AC09;
address constant COLLATERAL_ADDRESS = 0xb7C00000bcDEeF966b20B3D884B98E64d2b06b4f;
uint256 constant MCR = 150 * 1e16; //  110 * 1e16 -> 110%

uint256 constant MINUTE_DECAY_FACTOR = 999_037_758_833_783_500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (0%)
uint256 constant MAX_DEBT = 1e18 * 1_000_000_000; //  (1 billion)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 0; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4_294_967_295; // max uint32

// farming parameters
uint256 constant RETAIN_PERCENTAGE = 0; // 10_000 -> 100%
uint256 constant REFILL_PERCENTAGE = 0; // 10_000 -> 100%
