// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TroveManager } from "../../src/core/TroveManager.sol";

import { IBorrowerOperationsFacet } from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { IFactoryFacet } from "../../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../../src/core/interfaces/ILiquidationFacet.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";

import { Script, console } from "forge-std/Script.sol";

address constant TM_BEACON_ADDRESS = 0x7fe7de5d72633b981191EAEe2ccAEd95C77e79A9;

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeTMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IBeacon troveManagerBeacon = IBeacon(TM_BEACON_ADDRESS);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        // ITroveManager newTroveManagerImpl = new TroveManager();

        // console.log("block number:", block.number);
        // console.log("block timestamp:", block.timestamp);
        // console.log("current TroveManager Impl is deployed at", address(troveManagerBeacon.implementation()));
        // // upgrade to new trove manager implementation
        // troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
        // require(troveManagerBeacon.implementation() == address(newTroveManagerImpl), "implementation is not matched");

        // console.log("new TroveManager Impl is deployed at", address(newTroveManagerImpl));

        IFactoryFacet FAFacet = IFactoryFacet(0x95E5b977c8c33DE5b3B5D2216F1097C2017Bdf71);
        uint256 c = FAFacet.troveManagerCount();
        console.log("troveManagerCount:", c);
        vm.stopBroadcast();
    }
}
