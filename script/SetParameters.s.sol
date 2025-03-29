// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITroveManager} from "../src/core/interfaces/ITroveManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant TROVE_MANAGER_ADDRESS = 0xa03B86E93c98FE95caC2A6645fF271Bb67040eab;
uint256 constant MINUTE_DECAY_FACTOR = 999_037_758_833_783_500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (0%)
uint256 constant MAX_DEBT = 1e18 * 1_000_000_000;
uint256 constant MCR = 170 * 1e16; //  110 * 1e16 -> 110%
uint128 constant REWARD_RATE = 0; 
uint32 constant TM_CLAIM_START_TIME = 4_294_967_295; // max uint32

contract SetParametersScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    ITroveManager internal TM;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        TM = ITroveManager(TROVE_MANAGER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        TM.setParameters(
            MINUTE_DECAY_FACTOR,
            REDEMPTION_FEE_FLOOR,
            MAX_REDEMPTION_FEE,
            BORROWING_FEE_FLOOR,
            MAX_BORROWING_FEE,
            INTEREST_RATE_IN_BPS,
            MAX_DEBT,
            MCR,
            REWARD_RATE,
            TM_CLAIM_START_TIME
        );

        console2.log("Set TroveManager parameters");
        console2.log("TROVE_MANAGER_ADDRESS: ", TROVE_MANAGER_ADDRESS);
        console2.log("MINUTE_DECAY_FACTOR: ", MINUTE_DECAY_FACTOR);
        console2.log("REDEMPTION_FEE_FLOOR: ", REDEMPTION_FEE_FLOOR);
        console2.log("MAX_REDEMPTION_FEE: ", MAX_REDEMPTION_FEE);
        console2.log("BORROWING_FEE_FLOOR: ", BORROWING_FEE_FLOOR);
        console2.log("MAX_BORROWING_FEE: ", MAX_BORROWING_FEE);
        console2.log("INTEREST_RATE_IN_BPS: ", INTEREST_RATE_IN_BPS);
        console2.log("MAX_DEBT: ", MAX_DEBT);
        console2.log("MCR: ", MCR);
        console2.log("REWARD_RATE: ", REWARD_RATE);
        console2.log("TM_CLAIM_START_TIME: ", TM_CLAIM_START_TIME);

        vm.stopBroadcast();
    }
}
