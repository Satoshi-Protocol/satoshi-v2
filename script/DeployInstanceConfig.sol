// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

address constant SATOSHI_X_APP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
address constant REWARD_MANAGER_ADDRESS = 0xA11c3CAC45606C5b341B729332c2FA31bE896eb2;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x00072C48501f53Cb2Bb9EFCdD7A0Ee569cF9428f;
address constant COLLATERAL_ADDRESS = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 0; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
