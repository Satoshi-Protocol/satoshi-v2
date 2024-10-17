// SPDX-License-Identifier: UNLICENSED
import {Script, console} from "forge-std/Script.sol";
import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {ISatoshiXApp} from "../src/interfaces/ISatoshiXApp.sol";

contract DeploySetupScript is Script {
    uint256 internal immutable DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    SatoshiXApp satoshiXApp;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);
    }

    function run() public {
        satoshiXApp = new SatoshiXApp();
    }
}
