// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SAFE_VAULT_ADDRESS = 0x81aa1Ea364e4b697E45CFB903fD9BAd0e60908f6;
address constant TO = 0x600562418BD2534dCCA75D519c020166014F97c7;
bool constant IS_VALID = true;

contract SetWhitelistScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    SafeVault internal safeVault;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        safeVault = SafeVault(SAFE_VAULT_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        safeVault.setWhitelist(TO, IS_VALID);

        console2.log("Whitelist set for address:", TO, "with status:", IS_VALID);

        vm.stopBroadcast();
    }
}
