// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { NexusYieldManagerFacet } from "../../src/core/facets/NexusYieldManagerFacet.sol";
import { INexusYieldManagerFacet } from "../../src/core/interfaces/INexusYieldManagerFacet.sol";

import { ISatoshiXApp } from "../../src/core/interfaces/ISatoshiXApp.sol";
import { IERC2535DiamondCutInternal } from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";

import { Script, console2 } from "forge-std/Script.sol";

address payable constant SATOSHI_X_APP_ADDRESS = payable(0xd4b0eEcF327c0F1B43d487FEcFD2eA56E746A72b);
address constant COLLATERAL_ADDRESS = 0x9827431e8b77E87C9894BD50B055D6BE56bE0030;

contract UpgradeNYMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        address newNYMImpl = address(new NexusYieldManagerFacet());

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = INexusYieldManagerFacet.getAssetConfig.selector;

        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](1);
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: newNYMImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        ISatoshiXApp XAPP = ISatoshiXApp(SATOSHI_X_APP_ADDRESS);
        // empty data
        bytes memory data = "";
        XAPP.diamondCut(facetCuts, address(0), data);

        console2.log("new NYMImpl:", newNYMImpl);

        // INexusYieldManagerFacet NYMFacet = INexusYieldManagerFacet(SATOSHI_X_APP_ADDRESS);
        // console2.log("NYMFacet.getAssetConfig.debtTokenMinted:", NYMFacet.getAssetConfig(COLLATERAL_ADDRESS).debtTokenMinted);

        vm.stopBroadcast();
    }
}
