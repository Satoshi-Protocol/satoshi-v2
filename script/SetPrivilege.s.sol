// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { Script, console } from "forge-std/Script.sol";

address constant SATOSHI_XAPP_ADDRESS = 0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec;
address constant ACCOUNT = 0x2acfb3F0255793c29A9aab335E5D77d0261B886B;
bool constant IS_PRIVILEGED = true;

contract SetPrivilegeScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiXApp;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiXApp = SATOSHI_XAPP_ADDRESS;
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        INexusYieldManagerFacet(satoshiXApp).setPrivileged(ACCOUNT, IS_PRIVILEGED);

        console.log("Set privilege");
        console.log("Account:", ACCOUNT);
        console.log("Privileged:", IS_PRIVILEGED);

        vm.stopBroadcast();
    }
}
