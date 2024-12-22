// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Config {
    bytes32 internal constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "satUSD";

    uint256 internal constant CCR = 1500000000000000000; // 150%

    uint256 internal constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    /* stability pool */
    uint256 internal constant DEBT_TOKEN_DECIMALS = 18;
    uint256 internal constant DEBT_TOKEN_DECIMALS_BASE = 1e18;

    uint128 internal constant SUNSET_DURATION = 180 days;

    uint256 internal constant OSHI_EMISSION_DURATION = 5 * 365 days; // 5 years

    uint128 internal constant SP_MAX_REWARD_RATE = 63419583967529168; // 10_000_000e18 / (5 * 31536000)

    uint256 internal constant SCALE_FACTOR = 1e9;
    uint256 internal constant MIN_NET_DEBT_AMOUNT = 10e18;

    /* Factory */
    uint128 internal constant TM_MAX_REWARD_RATE = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))

    /* Liquidation */
    uint256 internal constant _100_PCT = 1000000000000000000; // 1e18 == 100%

    uint256 internal constant DEBT_GAS_COMPENSATION = 2e18;

    /* PriceFeedAggregator */
    uint256 public constant PRICE_TARGET_DIGITS = 18;

    /* Nexus Yield Manager */
    uint256 public constant TARGET_DIGITS = 18;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    uint256 public constant MANTISSA_ONE = 1e18;

    uint256 public constant ONE_DOLLAR = 1e18;
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

    uint256 constant LIQUIDATION_FEE = 200; //  (0.2%)

    /** Farming */
    uint256 constant FARMING_PRECISION = 1e4;
    
}
