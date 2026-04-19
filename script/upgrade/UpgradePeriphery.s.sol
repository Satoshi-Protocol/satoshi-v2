// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SatoshiPeriphery } from "../../src/core/helpers/SatoshiPeriphery.sol";
import { ISatoshiPeriphery } from "../../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant PERIPHERY_ADDRESS = 0x0a1cA3190579504761A0EFd0c94dfA2DeDe55bE2;
address constant OKX_ROUTER_ADDRESS = 0x79f7C6C6dc16Ed3154E85A8ef9c1Ef31CEFaEB19;
address constant OKX_APPROVE_ADDRESS = 0xD321ab5589d3E8FA5Df985ccFEf625022E2DD910;

interface IUUPSUgradeable {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function implementation() external view returns (address);
}

contract UpgradePeripheryScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IUUPSUgradeable internal uupsProxy;
    ISatoshiPeriphery internal periphery;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        uupsProxy = IUUPSUgradeable(PERIPHERY_ADDRESS);
        periphery = ISatoshiPeriphery(PERIPHERY_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        SatoshiPeriphery newPeripheryImpl = new SatoshiPeriphery();
        uupsProxy.upgradeToAndCall(address(newPeripheryImpl), "");

        console2.log("Upgraded Periphery to new implementation at", address(newPeripheryImpl));

        periphery.setOkxRouter(OKX_ROUTER_ADDRESS);
        periphery.setOkxApprove(OKX_APPROVE_ADDRESS);

        console2.log("Set OKX Router and Approve");
        console2.log("OKX Router:", OKX_ROUTER_ADDRESS);
        console2.log("OKX Approve:", OKX_APPROVE_ADDRESS);

        vm.stopBroadcast();
    }
}
