// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { DebtTokenViewer } from "../../src/utils/DebtTokenViewer.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant DEBT_TOKEN_ADDRESS = 0xceF6c74Ce218c0E1F48cA2430635D0a65Cd3737A;
uint256 constant VALID_AMOUNT = 10 * 10 ** 18;

contract DeployDebtTokenViewerScript is Script {
    DebtTokenViewer internal debtTokenViewer;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        debtTokenViewer = new DebtTokenViewer(DEBT_TOKEN_ADDRESS, VALID_AMOUNT);
        console2.log("DebtTokenViewer deployed at:", address(debtTokenViewer));

        vm.stopBroadcast();
    }
}
