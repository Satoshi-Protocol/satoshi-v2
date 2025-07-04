// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SwapRouter } from "../src/core/helpers/SwapRouter.sol";
import { ISwapRouter } from "../src/core/helpers/interfaces/ISwapRouter.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address constant OWNER = 0xd3e87B4B76E6F8bFf454AAFc2AD3271C5b317d47;
address constant SATOSHI_X_APP = 0x2863E3D0f29E2EEC6adEFC0dF0d3171DaD542c02;
address constant DEBT_TOKEN_ADDRESS = 0x8dD8b12d55C73c08294664a5915475eD1c8b1F6f;

contract DeploySwapRouterScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    ISwapRouter internal swapRouter;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        bytes memory data =
            abi.encodeCall(ISwapRouter.initialize, (IDebtToken(DEBT_TOKEN_ADDRESS), SATOSHI_X_APP, OWNER));
        address swapRouterImpl = address(new SwapRouter());
        swapRouter = ISwapRouter(address(new ERC1967Proxy(swapRouterImpl, data)));

        console2.log("SwapRouter deployed at:", address(swapRouter));
        console2.log("SwapRouter implementation address:", swapRouterImpl);

        vm.stopBroadcast();
    }
}
