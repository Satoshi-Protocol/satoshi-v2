// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0x8dD8b12d55C73c08294664a5915475eD1c8b1F6f;
address constant RELY_ADDRESS = 0xFbDdd16303a7bC37b19448e738b21ECdAC0fA8d0;

contract SetDebtTokenRelyScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IDebtToken internal debtToken;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        debtToken = IDebtToken(DEBT_TOKEN_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        debtToken.rely(RELY_ADDRESS);

        console2.log("Set rely");
        console2.log("DebtToken:", DEBT_TOKEN_ADDRESS);
        console2.log("Rely:", RELY_ADDRESS);

        vm.stopBroadcast();
    }
}
