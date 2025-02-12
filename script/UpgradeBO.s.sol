// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC2535DiamondCutInternal } from
    "../lib/solidstate-solidity/contracts/interfaces/IERC2535DiamondCutInternal.sol";
import { TroveManager } from "../src/core/TroveManager.sol";
import { BorrowerOperationsFacet } from "../src/core/facets/BorrowerOperationsFacet.sol";
import { IBorrowerOperationsFacet } from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { IFactoryFacet } from "../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../src/core/interfaces/ILiquidationFacet.sol";
import { ISatoshiXApp } from "../src/core/interfaces/ISatoshiXApp.sol";
import { ITroveManager } from "../src/core/interfaces/ITroveManager.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";

address payable constant SATOSHI_X_APP_ADDRESS = payable(0xd4b0eEcF327c0F1B43d487FEcFD2eA56E746A72b);
address constant TM_1 = 0xe7E23aD9c455c2Bcd3f7943437f4dFBe9149c0D2;
address constant TM_2 = 0xD63e204F0aB688403205cFC144CAdfc0D8C68458;

contract UpgradeBOScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    // IBeacon troveManagerBeacon = IBeacon(TM_BEACON_ADDRESS);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        address newBorrowerOperationsImpl = address(new BorrowerOperationsFacet());

        bytes4[] memory selectors = new bytes4[](18);
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

        bytes4[] memory newSelectors = new bytes4[](1);
        newSelectors[0] = IBorrowerOperationsFacet.forceResetTM.selector;

        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](2);
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: newBorrowerOperationsImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.REPLACE,
            selectors: selectors
        });
        facetCuts[1] = IERC2535DiamondCutInternal.FacetCut({
            target: newBorrowerOperationsImpl,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: newSelectors
        });

        ISatoshiXApp XAPP = ISatoshiXApp(SATOSHI_X_APP_ADDRESS);
        // empty data
        bytes memory data = "";
        XAPP.diamondCut(facetCuts, address(0), data);

        IBorrowerOperationsFacet BOFacet = IBorrowerOperationsFacet(SATOSHI_X_APP_ADDRESS);
        (uint256 totalPricedCollateral, uint256 totalDebt) = BOFacet.getGlobalSystemBalances();
        console2.log("totalPricedCollateral:", totalPricedCollateral);
        console2.log("totalDebt:", totalDebt);

        ITroveManager[] memory _troveManagers = new ITroveManager[](2);
        _troveManagers[0] = ITroveManager(TM_1);
        _troveManagers[1] = ITroveManager(TM_2);
        BOFacet.forceResetTM(_troveManagers);

        (totalPricedCollateral, totalDebt) = BOFacet.getGlobalSystemBalances();
        console2.log("totalPricedCollateral:", totalPricedCollateral);
        console2.log("totalDebt:", totalDebt);

        IFactoryFacet factoryFacet = IFactoryFacet(SATOSHI_X_APP_ADDRESS);
        uint256 c = factoryFacet.troveManagerCount();
        console2.log("TroveManager count:", c);

        ITroveManager t = factoryFacet.troveManagers(0);
        (IERC20 collateralToken, uint16 index) = BOFacet.troveManagersData(t);
        console2.log("TroveManager 0:", address(t));
        console2.log("collateralToken:", address(collateralToken));
        console2.log("index:", index);

        t = factoryFacet.troveManagers(1);
        (collateralToken, index) = BOFacet.troveManagersData(t);
        console2.log("TroveManager 1:", address(t));
        console2.log("collateralToken:", address(collateralToken));
        console2.log("index:", index);

        // t = factoryFacet.troveManagers(2);
        // (collateralToken, index) = BOFacet.troveManagersData(t);
        // console2.log("TroveManager 2:", address(t));
        // console2.log("collateralToken:", address(collateralToken));
        // console2.log("index:", index);

        // t = factoryFacet.troveManagers(3);
        // (collateralToken, index) = BOFacet.troveManagersData(t);
        // console2.log("TroveManager 3:", address(t));
        // console2.log("collateralToken:", address(collateralToken));
        // console2.log("index:", index);

        // t = factoryFacet.troveManagers(4);
        // (collateralToken, index) = BOFacet.troveManagersData(t);
        // console2.log("TroveManager 4:", address(t));
        // console2.log("collateralToken:", address(collateralToken));
        // console2.log("index:", index);

        vm.stopBroadcast();
    }
}
