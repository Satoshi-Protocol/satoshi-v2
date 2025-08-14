// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { IVaultManager } from "../../src/vault/interfaces/IVaultManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant VAULT_MANAGER_ADDRESS = 0xc473754a6e35cC4F45316F9faaeF0a3a86D90E4e;
address constant TROVE_MANAGER_ADDRESS = 0x6d991Eb34321609889812050bC7f4604Eb0bfF26;
uint256 constant AMOUNT = 500 * 1e8;

contract TransferCollToTroveManagerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IVaultManager internal vaultManager;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        vaultManager = IVaultManager(VAULT_MANAGER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        vaultManager.transferCollToTroveManager(TROVE_MANAGER_ADDRESS, AMOUNT);

        console2.log("Transferred", AMOUNT, "collateral to TroveManager at:", TROVE_MANAGER_ADDRESS);

        vm.stopBroadcast();
    }
}
