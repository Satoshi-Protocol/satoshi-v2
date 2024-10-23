// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script, console} from "forge-std/Script.sol";
// import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";
// import {DeployBase} from "./utils/DeployBase.sol";

// contract DeployDebtToken is Script, DeployBase {
//     uint256 public constant MOCK_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
//     address public satoshiXApp = 0x1234567890123456789012345678901234567890;

//     function run() public {
//         vm.startBroadcast(MOCK_PK);

//         _deployDebtToken();

//         vm.stopBroadcast();
//     }
// }
