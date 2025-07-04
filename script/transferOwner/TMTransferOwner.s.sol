// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Script, console } from "forge-std/Script.sol";

address constant TM_PROXY_ADDRESS = 0x6d991Eb34321609889812050bC7f4604Eb0bfF26;
address constant NEW_OWNER_ADDRESS = 0x600562418BD2534dCCA75D519c020166014F97c7;

contract TMTransferOwnerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    OwnableUpgradeable internal TM_PROXY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        TM_PROXY = OwnableUpgradeable(TM_PROXY_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        TM_PROXY.transferOwnership(NEW_OWNER_ADDRESS);

        vm.stopBroadcast();
    }
}
