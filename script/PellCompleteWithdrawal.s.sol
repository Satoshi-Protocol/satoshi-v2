// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PellVault } from "../src/vault/PellVault.sol";
import { IVaultManager } from "../src/vault/interfaces/IVaultManager.sol";
import { Script, console } from "forge-std/Script.sol";

contract SetPrivilegeScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiXApp;
    IVaultManager vaultManager = IVaultManager(0x21d9a468196665AEc3d3c289EfF7BD5725507972);
    PellVault pellVault = PellVault(0x1F745AEC91A7349E4F846Ae1D94915ec4f6cF053);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        // construct the data
        address token = 0x796e4D53067FF374B89b2Ac101ce0c1f72ccaAc2;
        bytes memory data = pellVault.constructCompleteQueueWithdrawData(token);
        // execute the strategy
        vaultManager.executeStrategy(address(pellVault), data);

        vm.stopBroadcast();
    }
}
