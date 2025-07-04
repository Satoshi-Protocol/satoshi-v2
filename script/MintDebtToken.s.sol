// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0xb4818BB69478730EF4e33Cc068dD94278e2766cB;
address constant MINTER_ADDRESS = 0xB08337aA8667e8CB0D9fF7d9003CEe15924bBf77;
uint256 constant MINT_AMOUNT = 500_000 * 1e18;

contract MintDebtTokenScript is Script {
    uint256 internal MINTER_PRIVATE_KEY;
    IDebtToken internal debtToken;

    function setUp() public {
        MINTER_PRIVATE_KEY = uint256(vm.envBytes32("MINTER_PRIVATE_KEY"));
        debtToken = IDebtToken(DEBT_TOKEN_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(MINTER_PRIVATE_KEY);

        debtToken.mint(MINTER_ADDRESS, MINT_AMOUNT);

        console2.log("Minting DebtToken");
        console2.log("DebtToken:", DEBT_TOKEN_ADDRESS);
        console2.log("Mint Amount:", MINT_AMOUNT);

        vm.stopBroadcast();
    }
}
