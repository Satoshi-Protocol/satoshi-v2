// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0x1958853A8BE062dc4f401750Eb233f5850F0D0d2;
address constant AUTH_ADDRESS = 0x5cD923FB3A229813E53253A37dcE0B1d8Aee5296;

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
