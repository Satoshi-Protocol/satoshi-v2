// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { SafeVault } from "../../../src/vault/SafeVault.sol";
import { IVault } from "../../../src/vault/interfaces/IVault.sol";
import { IVaultManager } from "../../../src/vault/interfaces/IVaultManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant VAULT_MANAGER_ADDRESS = 0xc473754a6e35cC4F45316F9faaeF0a3a86D90E4e;
address constant SAFE_VAULT_ADDRESS = 0x8df0452267d6A166CB51967Df5188D83D29D14fB;
address constant TOKEN_ADDRESS = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
address constant TO = 0x2acfb3F0255793c29A9aab335E5D77d0261B886B;
uint256 constant AMOUNT = 0.363267 * 1e18;

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
