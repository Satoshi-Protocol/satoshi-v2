// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SAFE_VAULT_ADDRESS = 0x9Dda31F8a07B216AB5E153456DE251E0ed2e6372;
address constant TO = 0x1234567890123456789012345678901234567890;
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
