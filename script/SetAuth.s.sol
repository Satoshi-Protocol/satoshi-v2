// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0x70654AaD8B7734dc319d0C3608ec7B32e03FA162;
address constant AUTH_ADDRESS = 0xFbDdd16303a7bC37b19448e738b21ECdAC0fA8d0;

contract SetAuthScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IDebtToken internal debtToken;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        debtToken = IDebtToken(DEBT_TOKEN_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        debtToken.rely(AUTH_ADDRESS);

        console.log("Set auth");
        console.log("DebtToken address:", DEBT_TOKEN_ADDRESS);
        console.log("Auth address:", AUTH_ADDRESS);

        vm.stopBroadcast();
    }
}
