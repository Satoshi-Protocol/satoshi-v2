// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SwapRouter } from "../../src/core/helpers/SwapRouter.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant SWAP_ROUTER_ADDRESS = 0x53a19d48d1cFB1499AAF8e26420006dE224d4b26;

interface IUUPSUgradeable {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function implementation() external view returns (address);
}

contract UpgradeSwapRouterScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IUUPSUgradeable internal swapRouter;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        swapRouter = IUUPSUgradeable(SWAP_ROUTER_ADDRESS);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        SwapRouter newSwapRouter = new SwapRouter();
        swapRouter.upgradeToAndCall(address(newSwapRouter), "");

        console2.log("Upgraded SwapRouter to new implementation at", address(newSwapRouter));

        vm.stopBroadcast();
    }
}
