// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "./utils/Deployer.sol";

contract DeployHelpersScript is Script {
    using Deployer for address;
    using stdJson for *;

    uint256 public constant MOCK_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address satoshiXApp;

    address multiCollateralHintHelpers;
    address troveHelper;
    address multiTroveGetter;
    address troveManagerGetters;

    function setUp() public {
        satoshiXApp = Deployer.getSatoshiXApp();
        console.log("SatoshiXApp: ", satoshiXApp);
    }

    function run() public {
        vm.startBroadcast(MOCK_PK);

        (multiCollateralHintHelpers, troveHelper, multiTroveGetter, troveManagerGetters) =
            Deployer._deployHelpers(satoshiXApp);

        console.log("======= HELPERS =======");
        console.log("MultiCollateralHintHelpers: ", multiCollateralHintHelpers);
        console.log("TroveHelper: ", address(troveHelper));
        console.log("MultiTroveGetter: ", address(multiTroveGetter));
        console.log("TroveManagerGetters: ", address(troveManagerGetters));

        vm.stopBroadcast();
    }
}
