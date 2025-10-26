// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0xb4818BB69478730EF4e33Cc068dD94278e2766cB;
address constant AUTH_ADDRESS = 0x916a53b9aA87A3370cD5B1ce6ed8f1F5Aa5eAbFb;

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
