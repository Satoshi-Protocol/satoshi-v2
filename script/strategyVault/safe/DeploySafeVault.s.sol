// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IVault } from "../../../src/vault/interfaces/IVault.sol";
import { IVaultManager } from "../../../src/vault/interfaces/IVaultManager.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant VAULT_MANAGER_ADDRESS = 0x9Dda31F8a07B216AB5E153456DE251E0ed2e6372;
address constant DEBT_TOKEN_ADDRESS = 0x70654AaD8B7734dc319d0C3608ec7B32e03FA162;

contract DeploySafeVaultScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    IVaultManager internal vaultManager;
    SafeVault internal safeVault;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        vaultManager = IVaultManager(VAULT_MANAGER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        assert(address(safeVault) == address(0));
        bytes memory initData = abi.encode(VAULT_MANAGER_ADDRESS, DEBT_TOKEN_ADDRESS);
        bytes memory data = abi.encodeCall(IVault.initialize, (initData));
        address safeVaultImpl = address(new SafeVault());
        safeVault = SafeVault(address(new ERC1967Proxy(safeVaultImpl, data)));

        vaultManager.setWhiteListVault(address(safeVault), true);

        console2.log("SafeVault deployed at:", address(safeVault));
        console2.log("SafeVault implementation address:", safeVaultImpl);

        vm.stopBroadcast();
    }
}
