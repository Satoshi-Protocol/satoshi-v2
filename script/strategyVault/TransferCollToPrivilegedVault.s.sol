// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant TROVE_MANAGER_ADDRESS = 0xDAc0551246A7F75503e8C908456005E828C35A40;
uint256 constant AMOUNT = 500 * 1e18;

contract TransferCollToPrivilegedVaultScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    ITroveManager internal TM;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        TM = ITroveManager(TROVE_MANAGER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        TM.transferCollToPrivilegedVault(AMOUNT);

        console2.log("Transferred", AMOUNT, "collateral to privileged vault");

        vm.stopBroadcast();
    }
}
