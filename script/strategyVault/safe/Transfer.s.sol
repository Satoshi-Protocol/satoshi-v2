// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IVault } from "../../../src/vault/interfaces/IVault.sol";
import { IVaultManager } from "../../../src/vault/interfaces/IVaultManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant VAULT_MANAGER_ADDRESS = 0x9Dda31F8a07B216AB5E153456DE251E0ed2e6372;
address constant SAFE_VAULT_ADDRESS = 0xE8c5b4517610006C1fb0eD5467E01e4bAd43558D;
address constant TOKEN_ADDRESS = 0x8d2757EA27AaBf172DA4CCa4e5474c76016e3dC5;
address constant TO = 0x1234567890123456789012345678901234567890;
uint256 constant AMOUNT = 150 * 1e18;

contract TransferScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IVaultManager internal vaultManager;
    SafeVault internal safeVault;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        vaultManager = IVaultManager(VAULT_MANAGER_ADDRESS);
        safeVault = SafeVault(SAFE_VAULT_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        assert(address(vaultManager) != address(0));
        bytes memory data = safeVault.constructTransferData(TOKEN_ADDRESS, TO, AMOUNT);
        vaultManager.executeStrategy(SAFE_VAULT_ADDRESS, data);

        console2.log("Deposited", AMOUNT, "tokens into SafeVault at", SAFE_VAULT_ADDRESS);

        vm.stopBroadcast();
    }
}
