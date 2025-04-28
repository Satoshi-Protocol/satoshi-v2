// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_X_APP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
address constant REWARD_MANAGER_ADDRESS = 0xA11c3CAC45606C5b341B729332c2FA31bE896eb2;
address constant VAULT_MANAGER_ADDRESS = 0xc473754a6e35cC4F45316F9faaeF0a3a86D90E4e;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xb8374e4DfF99202292da2FE34425e1dE665b67E6;
address constant COLLATERAL_ADDRESS = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
uint256 constant MCR = 110 * 1e16; //  110 * 1e16 -> 110%

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
