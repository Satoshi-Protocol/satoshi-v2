// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Script, console } from "forge-std/Script.sol";

address constant TM_BEACON_ADDRESS = 0x0C309bDCaFf14ac240f6021FceaE11f40Bd0e939;
address constant NEW_OWNER_ADDRESS = 0x600562418BD2534dCCA75D519c020166014F97c7;

contract TMTransferOwnerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    OwnableUpgradeable internal TM_BEACON;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        TM_BEACON = OwnableUpgradeable(TM_BEACON_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        TM_BEACON.transferOwnership(NEW_OWNER_ADDRESS);

        vm.stopBroadcast();
    }
}
