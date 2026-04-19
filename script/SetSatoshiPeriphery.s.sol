// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";

import { ISatoshiPeriphery } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";

address constant OKX_ROUTER_ADDRESS = 0x0000000000000000000000000000000000008001;
address constant OKX_APPROVE_ADDRESS = 0x0000000000000000000000000000000000008002;
address constant PERIPHERY_ADDRESS = 0x0000000000000000000000000000000000008003;

contract SetSatoshiPeriphery is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    ISatoshiPeriphery internal periphery;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        periphery = ISatoshiPeriphery(PERIPHERY_ADDRESS);
    }

    function run() external {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        periphery.setOkxRouter(OKX_ROUTER_ADDRESS);
        periphery.setOkxApprove(OKX_APPROVE_ADDRESS);

        console2.log("Set OKX Router and Approve");
        console2.log("OKX Router:", OKX_ROUTER_ADDRESS);
        console2.log("OKX Approve:", OKX_APPROVE_ADDRESS);

        vm.stopBroadcast();
    }
}
