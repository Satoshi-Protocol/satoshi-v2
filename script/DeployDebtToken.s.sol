// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script, console} from "forge-std/Script.sol";
// import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";
// import {Deployer} from "./utils/Deployer.sol";

// contract DeployDebtToken is Script {
//     uint256 internal DEPLOYMENT_PRIVATE_KEY;
//     uint256 internal OWNER_PRIVATE_KEY;
//     address public deployer;
//     address public satoshiCoreOwner;

//     address public constant LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;
//     address public satoshiXApp;

//     IDebtToken debtToken;

//     function setUp() external {
//         DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
//         assert(DEPLOYMENT_PRIVATE_KEY != 0);
//         deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);

//         OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
//         assert(OWNER_PRIVATE_KEY != 0);
//         satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);

//         satoshiXApp = Deployer.getSatoshiXApp();
//         console.log("XApp: ", satoshiXApp);
//     }

//     function run() public {
//         _deployDebtToken();
//     }

//     function _deployDebtToken() internal {
//         vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

//         debtToken = Deployer._deployDebtToken(satoshiXApp, LZ_ENDPOINT, satoshiCoreOwner);
//         console.log("DebtToken: ", address(debtToken));

//         vm.stopBroadcast();
//     }
// }
