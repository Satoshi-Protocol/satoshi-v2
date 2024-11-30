// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";

contract SatoshiPeripheryTest is DeployBase {
    function setUp() public override {
        super.setUp();
        console.log("SatoshiPeripheryTest.setUp", address(satoshiPeriphery));
    }

    function test_deploy() public {
        address[] memory addresses = satoshiXApp.facetAddresses();
        assert(addresses.length > 0);
    }

    
}
