// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "./utils/Deployer.sol";

contract DeployHelpersScript is Script {
    using Deployer for address;

    address satoshiXApp = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    address multiCollateralHintHelpers;
    address troveHelper;
    address multiTroveGetter;
    address troveManagerGetters;

    function run() public {
        (multiCollateralHintHelpers, troveHelper, multiTroveGetter, troveManagerGetters) =
            Deployer._deployHelpers(satoshiXApp);

        console.log("======= HELPERS =======");
        console.log("MultiCollateralHintHelpers: ", multiCollateralHintHelpers);
        console.log("TroveHelper: ", address(troveHelper));
        console.log("MultiTroveGetter: ", address(multiTroveGetter));
        console.log("TroveManagerGetters: ", address(troveManagerGetters));
    }
}
