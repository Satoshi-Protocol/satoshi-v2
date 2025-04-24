// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ITroveManager } from "../src/core/interfaces/ITroveManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant TROVE_MANAGER_ADDRESS = 0x01DF7D28c51639F2f2F95dcF2FdFF374269327B0;
address constant VAULT_MANAGER_ADDRESS = 0x9Dda31F8a07B216AB5E153456DE251E0ed2e6372;
uint256 constant RETAIN_PERCENTAGE = 0; // 0%
uint256 constant REFILL_PERCENTAGE = 10_000; // 100%

contract SetCDPFarmingScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    ITroveManager internal TM;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        TM = ITroveManager(TROVE_MANAGER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        TM.setVaultManager(VAULT_MANAGER_ADDRESS);
        TM.setFarmingParams(RETAIN_PERCENTAGE, REFILL_PERCENTAGE);

        console2.log("Set CDP farming params");
        console2.log("Vault Manager Address:", VAULT_MANAGER_ADDRESS);
        console2.log("Retain Percentage:", RETAIN_PERCENTAGE);
        console2.log("Refill Percentage:", REFILL_PERCENTAGE);

        vm.stopBroadcast();
    }
}
