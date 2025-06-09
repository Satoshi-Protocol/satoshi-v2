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

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeGracePeriodScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        _upgradeBOFaucet();
        _upgradeLiquidationFacet();
        _upgradeInitializer();

        // initV2
        Initializer initializer = Initializer(SATOSHI_X_APP_ADDRESS);
        initializer.initV2();

        vm.stopBroadcast();
    }

    function _diamondCut(
        address target,
        bytes4[] memory selectors,
        bytes4[] memory newSelectors,
        bytes memory data
    )
        internal
    {
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](2);

        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: target,
            action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE,
            selectors: selectors
        });

        facetCuts[1] = IERC2535DiamondCutInternal.FacetCut({
            target: target,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: newSelectors
        });

        ISatoshiXApp XAPP = ISatoshiXApp(SATOSHI_X_APP_ADDRESS);
        XAPP.diamondCut(facetCuts, address(0), data);
    }

    function _upgradeBOFaucet() internal {
        address newBorrowerOperationsImpl = address(new BorrowerOperationsFacet());

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

        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = IBorrowerOperationsFacet.syncGracePeriod.selector;

        _diamondCut(newBorrowerOperationsImpl, selectors, newSelectors, "");
    }

    function _upgradeLiquidationFacet() internal {
        address newLiquidationFacetImpl = address(new LiquidationFacet());
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[1] = ILiquidationFacet.liquidate.selector;
        selectors[2] = ILiquidationFacet.liquidateTroves.selector;

        bytes4[] memory newSelectors = new bytes4[](2);
        newSelectors[0] = ILiquidationFacet.setGracePeriod.selector;
        newSelectors[1] = ILiquidationFacet.syncGracePeriod.selector;

        _diamondCut(newLiquidationFacetImpl, selectors, newSelectors, "");
    }

    function _upgradeInitializer() internal {
        Initializer initializer = new Initializer();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Initializer.init.selector;
        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = Initializer.initV2.selector;
        bytes memory data = abi.encodeWithSelector(Initializer.initV2.selector);
        _diamondCut(address(initializer), selectors, newSelectors, data);
    }
}
