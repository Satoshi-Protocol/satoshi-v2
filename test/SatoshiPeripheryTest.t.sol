// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestConfig.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";

contract SatoshiPeripheryTest is DeployBase {
    function setUp() public override {
        super.setUp();
    }

    function test_deploy() public {
        // _deployMockTroveManager(DEPLOYER);
    }
    
}
