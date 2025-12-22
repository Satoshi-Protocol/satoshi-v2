// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0xb4818BB69478730EF4e33Cc068dD94278e2766cB;
address constant ADDRESS = 0xb46470c666cbCF4581E26b833D5742Ce64007f0E;
uint256 constant BURN_AMOUNT = 565_000 * 1e18;

contract BurnDebtTokenScript is Script {
    uint256 internal MINTER_PRIVATE_KEY;
    IDebtToken internal debtToken;

    function setUp() public {
        MINTER_PRIVATE_KEY = uint256(vm.envBytes32("MINTER_PRIVATE_KEY"));
        debtToken = IDebtToken(DEBT_TOKEN_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(MINTER_PRIVATE_KEY);

        debtToken.burn(ADDRESS, BURN_AMOUNT);

        console2.log("Burning DebtToken");
        console2.log("DebtToken:", DEBT_TOKEN_ADDRESS);
        console2.log("Burn Amount:", BURN_AMOUNT);
        vm.stopBroadcast();
    }
}
