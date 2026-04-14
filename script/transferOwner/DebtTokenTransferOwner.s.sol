// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DebtToken } from "../../src/core/DebtToken.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0xceF6c74Ce218c0E1F48cA2430635D0a65Cd3737A; // replace with actual contract address
address constant NEW_OWNER = 0xE7fb85455158BBd3a9F024105852341A0cDde019; // replace with the new owner's address

contract TransferOwnerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    DebtToken internal debtToken;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        debtToken = DebtToken(DEBT_TOKEN_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        debtToken.transferOwnership(NEW_OWNER);
        assert(debtToken.owner() == NEW_OWNER);

        vm.stopBroadcast();

        console2.log("Ownership transferred to:", NEW_OWNER);
    }
}
