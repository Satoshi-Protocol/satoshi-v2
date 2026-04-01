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

        bytes4[] memory addSelectors = new bytes4[](1);
        addSelectors[0] = INexusYieldManagerFacet.getWeightedAssetRate.selector;

        bytes4[] memory replaceSelectors = new bytes4[](29);
        replaceSelectors[0] = INexusYieldManagerFacet.setAssetConfig.selector;
        replaceSelectors[1] = INexusYieldManagerFacet.sunsetAsset.selector;
        replaceSelectors[2] = INexusYieldManagerFacet.swapIn.selector;
        replaceSelectors[3] = INexusYieldManagerFacet.pause.selector;
        replaceSelectors[4] = INexusYieldManagerFacet.resume.selector;
        replaceSelectors[5] = INexusYieldManagerFacet.setPrivileged.selector;
        replaceSelectors[6] = INexusYieldManagerFacet.transferTokenToPrivilegedVault.selector;
        replaceSelectors[7] = INexusYieldManagerFacet.previewSwapOut.selector;
        replaceSelectors[8] = INexusYieldManagerFacet.previewSwapIn.selector;
        replaceSelectors[9] = INexusYieldManagerFacet.swapOutPrivileged.selector;
        replaceSelectors[10] = INexusYieldManagerFacet.swapInPrivileged.selector;
        replaceSelectors[11] = INexusYieldManagerFacet.scheduleSwapOut.selector;
        replaceSelectors[12] = INexusYieldManagerFacet.withdraw.selector;
        replaceSelectors[13] = INexusYieldManagerFacet.convertDebtTokenToAssetAmount.selector;
        replaceSelectors[14] = INexusYieldManagerFacet.convertAssetToDebtTokenAmount.selector;
        replaceSelectors[15] = INexusYieldManagerFacet.feeIn.selector;
        replaceSelectors[16] = INexusYieldManagerFacet.feeOut.selector;
        replaceSelectors[17] = INexusYieldManagerFacet.debtTokenMintCap.selector;
        replaceSelectors[18] = INexusYieldManagerFacet.dailyDebtTokenMintCap.selector;
        replaceSelectors[19] = INexusYieldManagerFacet.debtTokenMinted.selector;
        replaceSelectors[20] = INexusYieldManagerFacet.isUsingOracle.selector;
        replaceSelectors[21] = INexusYieldManagerFacet.swapWaitingPeriod.selector;
        replaceSelectors[22] = INexusYieldManagerFacet.debtTokenDailyMintCapRemain.selector;
        replaceSelectors[23] = INexusYieldManagerFacet.pendingWithdrawal.selector;
        replaceSelectors[24] = INexusYieldManagerFacet.pendingWithdrawals.selector;
        replaceSelectors[25] = INexusYieldManagerFacet.isNymPaused.selector;
        replaceSelectors[26] = INexusYieldManagerFacet.dailyMintCount.selector;
        replaceSelectors[27] = INexusYieldManagerFacet.isAssetSupported.selector;
        replaceSelectors[28] = INexusYieldManagerFacet.getAssetConfig.selector;

        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](2);
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: newNYMImpl, action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE, selectors: replaceSelectors
        });
        facetCuts[1] = IERC2535DiamondCutInternal.FacetCut({
            target: newNYMImpl, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: addSelectors
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
