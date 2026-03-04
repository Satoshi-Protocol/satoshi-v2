// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console } from "forge-std/Script.sol";

import { SatoshiPeriphery } from "../src/core/helpers/SatoshiPeriphery.sol";
import { ISatoshiPeriphery } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";

contract DeploySatoshiPeriphery is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        address debtToken = vm.envAddress("DEBT_TOKEN");
        address xApp = vm.envAddress("X_APP");
        address owner = vm.envAddress("OWNER");

        vm.startBroadcast(deployerKey);

        address peripheryImpl = address(new SatoshiPeriphery());
        bytes memory data =
            abi.encodeCall(ISatoshiPeriphery.initialize, (IDebtToken(debtToken), xApp, owner));
        ISatoshiPeriphery periphery = ISatoshiPeriphery(address(new ERC1967Proxy(peripheryImpl, data)));

        console.log("Implementation:", peripheryImpl);
        console.log("Proxy:", address(periphery));

        vm.stopBroadcast();
    }
}
