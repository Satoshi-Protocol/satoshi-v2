// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Config {
    bytes32 internal constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // During bootsrap period redemptions are not allowed
    uint256 public constant BOOTSTRAP_PERIOD = 14 days;
    uint256 internal constant CCR = 1_500_000_000_000_000_000; // 150%

    uint256 internal constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    /* stability pool */
    uint256 internal constant DEBT_TOKEN_DECIMALS = 18;
    uint256 internal constant DEBT_TOKEN_DECIMALS_BASE = 1e18;

    uint128 internal constant SUNSET_DURATION = 180 days;

    uint256 internal constant OSHI_EMISSION_DURATION = 5 * 365 days; // 5 years

    uint128 internal constant SP_MAX_REWARD_RATE = 63_419_583_967_529_168; // 10_000_000e18 / (5 * 31536000)

    uint256 internal constant SCALE_FACTOR = 1e9;

    /* Factory */
    uint128 internal constant TM_MAX_REWARD_RATE = 126_839_167_935_058_336; //  (20_000_000e18 / (5 * 31536000))

    /* Liquidation */
    uint256 internal constant _100_PCT = 1_000_000_000_000_000_000; // 1e18 == 100%

    uint256 internal constant _110_PCT = 1_100_000_000_000_000_000; // 110%

    /* PriceFeedAggregator */
    uint256 public constant PRICE_TARGET_DIGITS = 18;

    /* Nexus Yield Manager */
    uint256 public constant TARGET_DIGITS = 18;

    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    uint256 public constant MANTISSA_ONE = 1e18;

    uint256 public constant ONE_DOLLAR = 1e18;

    /**
     * Farming
     */
    uint256 constant FARMING_PRECISION = 1e4;
}
