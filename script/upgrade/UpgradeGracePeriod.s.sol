// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Initializer } from "../../src/core/Initializer.sol";
import { TroveManager } from "../../src/core/TroveManager.sol";
import { BorrowerOperationsFacet } from "../../src/core/facets/BorrowerOperationsFacet.sol";
import { LiquidationFacet } from "../../src/core/facets/LiquidationFacet.sol";
import { IBorrowerOperationsFacet } from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { IFactoryFacet } from "../../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../../src/core/interfaces/ILiquidationFacet.sol";

import { ISatoshiXApp } from "../../src/core/interfaces/ISatoshiXApp.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { IERC2535DiamondCutInternal } from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";
import { Script, console } from "forge-std/Script.sol";

address payable constant SATOSHI_X_APP_ADDRESS = payable(0x07BbC5A83B83a5C440D1CAedBF1081426d0AA4Ec);
address payable constant TM_BEACON_ADDRESS = payable(0x00);

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

library UpgradeGracePeriodLib {
    function upgradeGracePeriod(address payable satoshiXApp) internal {
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](6);

        // BorrowerOperationsFacet
        address newBorrowerOperationsImpl = address(new BorrowerOperationsFacet());
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: newBorrowerOperationsImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE,
            selectors: getBOSelectors()
        });
        facetCuts[1] = IERC2535DiamondCutInternal.FacetCut({
            target: newBorrowerOperationsImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: getBONewSelectors()
        });

        // LiquidationFacet
        address newLiquidationFacetImpl = address(new LiquidationFacet());
        facetCuts[2] = IERC2535DiamondCutInternal.FacetCut({
            target: newLiquidationFacetImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE,
            selectors: getLiquidationSelectors()
        });
        facetCuts[3] = IERC2535DiamondCutInternal.FacetCut({
            target: newLiquidationFacetImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: getLiquidationNewSelectors()
        });

        // Initializer
        address newInitializerImpl = address(new Initializer());
        facetCuts[4] = IERC2535DiamondCutInternal.FacetCut({
            target: newInitializerImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE,
            selectors: getInitializerSelectors()
        });
        facetCuts[5] = IERC2535DiamondCutInternal.FacetCut({
            target: newInitializerImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: getInitializerNewSelectors()
        });

        // Upgrade and run initV2
        ISatoshiXApp XAPP = ISatoshiXApp(satoshiXApp);
        bytes memory data = abi.encodeWithSelector(Initializer.initV2.selector);
        XAPP.diamondCut(facetCuts, satoshiXApp, data);
    }

    function getBOSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](19);
        selectors[0] = IBorrowerOperationsFacet.addColl.selector;
        selectors[1] = IBorrowerOperationsFacet.adjustTrove.selector;
        selectors[2] = IBorrowerOperationsFacet.checkRecoveryMode.selector;
        selectors[3] = IBorrowerOperationsFacet.closeTrove.selector;
        selectors[4] = IBorrowerOperationsFacet.fetchBalances.selector;
        selectors[5] = IBorrowerOperationsFacet.getCompositeDebt.selector;
        selectors[6] = IBorrowerOperationsFacet.getGlobalSystemBalances.selector;
        selectors[7] = IBorrowerOperationsFacet.getTCR.selector;
        selectors[8] = IBorrowerOperationsFacet.isApprovedDelegate.selector;
        selectors[9] = IBorrowerOperationsFacet.minNetDebt.selector;
        selectors[10] = IBorrowerOperationsFacet.openTrove.selector;
        selectors[11] = IBorrowerOperationsFacet.removeTroveManager.selector;
        selectors[12] = IBorrowerOperationsFacet.repayDebt.selector;
        selectors[13] = IBorrowerOperationsFacet.setDelegateApproval.selector;
        selectors[14] = IBorrowerOperationsFacet.setMinNetDebt.selector;
        selectors[15] = IBorrowerOperationsFacet.troveManagersData.selector;
        selectors[16] = IBorrowerOperationsFacet.withdrawColl.selector;
        selectors[17] = IBorrowerOperationsFacet.withdrawDebt.selector;
        selectors[18] = IBorrowerOperationsFacet.forceResetTM.selector;
        return selectors;
    }

    function getBONewSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = IBorrowerOperationsFacet.syncGracePeriod.selector;
        return newSelectors;
    }

    function getLiquidationSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[1] = ILiquidationFacet.liquidate.selector;
        selectors[2] = ILiquidationFacet.liquidateTroves.selector;
        return selectors;
    }

    function getLiquidationNewSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = ILiquidationFacet.setGracePeriod.selector;
        return newSelectors;
    }

    function getInitializerSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Initializer.init.selector;
        return selectors;
    }

    function getInitializerNewSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = Initializer.initV2.selector;
        return newSelectors;
    }
}

contract UpgradeGracePeriodScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        UpgradeGracePeriodLib.upgradeGracePeriod(SATOSHI_X_APP_ADDRESS);
        IBeacon troveManagerBeacon = IBeacon(TM_BEACON_ADDRESS);
        address newTroveManagerImpl = address(new TroveManager());
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));

        vm.stopBroadcast();
    }
}
