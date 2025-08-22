// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { TroveManager } from "../../src/core/TroveManager.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { Script, console2 } from "forge-std/Script.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeTroveManagerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IBeacon troveManagerBeacon = IBeacon(0x0C309bDCaFf14ac240f6021FceaE11f40Bd0e939);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        ITroveManager newTroveManagerImpl = new TroveManager();

        console2.log("current TroveManager Impl is deployed at", address(troveManagerBeacon.implementation()));
        // upgrade to new trove manager implementation
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
        require(troveManagerBeacon.implementation() == address(newTroveManagerImpl), "implementation is not matched");

        console2.log("new TroveManager Impl is deployed at", address(newTroveManagerImpl));

        vm.stopBroadcast();
    }
}
