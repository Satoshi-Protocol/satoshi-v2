// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0x2031c8848775a5EFB7cfF2A4EdBE3F04c50A1478;
address constant AUTH_ADDRESS = 0xd4b0eEcF327c0F1B43d487FEcFD2eA56E746A72b;

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
