// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "./utils/DeployBase.sol";

contract DeployHelpersScript is Script, DeployBase {
    function run() public {
        _deployHelpers();
    }
}