// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { CygnusVault } from "../../../src/vault/CygnusVault.sol";
import { IVault } from "../../../src/vault/interfaces/IVault.sol";
import { IVaultManager } from "../../../src/vault/interfaces/IVaultManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant CYGNUS_VAULT_ADDRESS = 0xE8c5b4517610006C1fb0eD5467E01e4bAd43558D;
address constant TOKEN_ADDRESS = 0x8d2757EA27AaBf172DA4CCa4e5474c76016e3dC5;
address constant STRATEGY_ADDRESS = 0x3F772356E77F38B7d5432e29C7F16B66a49f9801;
address constant ST_TOKEN_ADDRESS = 0x95B8333F67703c8fC5769ced768b5697E54009F8;

contract SetCygnusVaultConfigScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    CygnusVault internal cygnusVault;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        cygnusVault = CygnusVault(CYGNUS_VAULT_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        assert(address(cygnusVault) != address(0));
        cygnusVault.setTokenStrategy(TOKEN_ADDRESS, STRATEGY_ADDRESS);
        cygnusVault.setStToken(TOKEN_ADDRESS, ST_TOKEN_ADDRESS);

        console2.log("Set strategy for token", TOKEN_ADDRESS, "to", STRATEGY_ADDRESS);

        vm.stopBroadcast();
    }
}
