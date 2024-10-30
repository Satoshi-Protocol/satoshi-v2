// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "./utils/Deployer.sol";
import {Config} from "./utils/Config.sol";

contract DeployHelpersScript is Script {
    using Deployer for address;
    using stdJson for *;

    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public deployer;
    address public satoshiCoreOwner;
    address public WETH;

    address multiCollateralHintHelpers;
    address troveHelper;
    address multiTroveGetter;
    address troveManagerGetters;
    address satoshiPeriphery;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);

        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        assert(OWNER_PRIVATE_KEY != 0);
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);

        Config.ConfigData memory config = abi.decode(Config.getConfig(), (Config.ConfigData));
        WETH = config.weth;
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        address satoshiXApp = Deployer.getContractAddress("Deploy", "SatoshiXApp");
        address debtImpl = Deployer.getContractAddress("Deploy", "DebtToken");
        address debtToken = Deployer.getERC1967ProxyAddress("Deploy", debtImpl);

        console.log(debtImpl);
        console.log(debtToken);

        (multiCollateralHintHelpers, troveHelper, multiTroveGetter, troveManagerGetters) =
            Deployer._deployHelpers(satoshiXApp);
        satoshiPeriphery = Deployer._deployPeriphery(debtToken, WETH, satoshiXApp, satoshiCoreOwner);

        console.log("======= HELPERS =======");
        console.log("MultiCollateralHintHelpers: ", multiCollateralHintHelpers);
        console.log("TroveHelper: ", address(troveHelper));
        console.log("MultiTroveGetter: ", address(multiTroveGetter));
        console.log("TroveManagerGetters: ", address(troveManagerGetters));
        console.log("SatoshiPeriphery: ", address(satoshiPeriphery));

        vm.stopBroadcast();
    }
}
