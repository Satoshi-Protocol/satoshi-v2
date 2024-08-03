// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DeployBase} from "./utils/DeployBase.t.sol";

contract DeployTest is DeployBase {
    function setUp() public override {
        super.setUp();
    }

    function test_deploy() public {
        address[] memory addresses = satoshiXApp.facetAddresses();
    }
}
