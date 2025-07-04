// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Script, console } from "forge-std/Script.sol";

address constant PERIPHERY_PROXY_ADDRESS = 0x0a1cA3190579504761A0EFd0c94dfA2DeDe55bE2;
address constant NEW_OWNER_ADDRESS = 0x600562418BD2534dCCA75D519c020166014F97c7;

contract PeripheryTransferOwnerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    OwnableUpgradeable internal PERIPHERY_PROXY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        PERIPHERY_PROXY = OwnableUpgradeable(PERIPHERY_PROXY_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        PERIPHERY_PROXY.transferOwnership(NEW_OWNER_ADDRESS);

        vm.stopBroadcast();
    }
}
