// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "./utils/Deployer.sol";

contract DeployHelpersScript is Script {
    using Deployer for address;
    using stdJson for *;

    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    address satoshiXApp;

    address multiCollateralHintHelpers;
    address troveHelper;
    address multiTroveGetter;
    address troveManagerGetters;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);

        satoshiXApp = Deployer.getSatoshiXApp();
        console.log("SatoshiXApp: ", satoshiXApp);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

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
