// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IVault } from "../../../src/vault/interfaces/IVault.sol";
import { IVaultManager } from "../../../src/vault/interfaces/IVaultManager.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant VAULT_MANAGER_ADDRESS = 0xc473754a6e35cC4F45316F9faaeF0a3a86D90E4e;
address constant DEBT_TOKEN_ADDRESS = 0xb4818BB69478730EF4e33Cc068dD94278e2766cB;

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
