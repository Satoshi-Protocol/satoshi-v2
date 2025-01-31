// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Config {
    bytes32 internal constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    uint256 internal constant CCR = 1500000000000000000; // 150%

    uint256 internal constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    /* stability pool */
    uint256 internal constant DEBT_TOKEN_DECIMALS = 18;
    uint256 internal constant DEBT_TOKEN_DECIMALS_BASE = 1e18;

    uint128 internal constant SUNSET_DURATION = 180 days;

    uint256 internal constant OSHI_EMISSION_DURATION = 5 * 365 days; // 5 years

    uint128 internal constant SP_MAX_REWARD_RATE = 63419583967529168; // 10_000_000e18 / (5 * 31536000)

    uint256 internal constant SCALE_FACTOR = 1e9;

    /* Factory */
    uint128 internal constant TM_MAX_REWARD_RATE = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))

    /* Liquidation */
    uint256 internal constant _100_PCT = 1000000000000000000; // 1e18 == 100%

    /* PriceFeedAggregator */
    uint256 public constant PRICE_TARGET_DIGITS = 18;

    /* Nexus Yield Manager */
    uint256 public constant TARGET_DIGITS = 18;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    uint256 public constant MANTISSA_ONE = 1e18;

    uint256 public constant ONE_DOLLAR = 1e18;

    /**
     * Farming
     */
    uint256 constant FARMING_PRECISION = 1e4;
}
