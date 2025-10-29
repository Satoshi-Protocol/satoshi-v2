// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Initializer } from "../../src/core/Initializer.sol";
import { IBorrowerOperationsFacet } from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ICoreFacet } from "../../src/core/interfaces/ICoreFacet.sol";
import { IFactoryFacet } from "../../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../../src/core/interfaces/ILiquidationFacet.sol";
import { INexusYieldManagerFacet } from "../../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { IStabilityPoolFacet } from "../../src/core/interfaces/IStabilityPoolFacet.sol";
import { IERC2535DiamondCutInternal } from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";

import { Vm } from "forge-std/Vm.sol";

library Builder {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function buildCoreFacet(address coreFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(coreFacet != address(0), "Builder: coreFacet address must be non-zero");

        uint8 selectorsLength = 12;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = ICoreFacet.setFeeReceiver.selector;
        selectors[selectorIndex++] = ICoreFacet.setRewardManager.selector;
        selectors[selectorIndex++] = ICoreFacet.setPaused.selector;
        selectors[selectorIndex++] = ICoreFacet.feeReceiver.selector;
        selectors[selectorIndex++] = ICoreFacet.rewardManager.selector;

        selectors[selectorIndex++] = ICoreFacet.paused.selector;
        selectors[selectorIndex++] = ICoreFacet.startTime.selector;
        selectors[selectorIndex++] = ICoreFacet.debtToken.selector;
        selectors[selectorIndex++] = ICoreFacet.gasCompensation.selector;
        selectors[selectorIndex++] = ICoreFacet.sortedTrovesBeacon.selector;

        selectors[selectorIndex++] = ICoreFacet.troveManagerBeacon.selector;
        selectors[selectorIndex++] = ICoreFacet.communityIssuance.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: coreFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildBorrowerOperationsFacet(address borrowerOperationsFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(borrowerOperationsFacet != address(0), "Builder: borrowerOperationsFacet address must be non-zero");

        uint8 selectorsLength = 18;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = IBorrowerOperationsFacet.isApprovedDelegate.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.setDelegateApproval.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.addColl.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.adjustTrove.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.closeTrove.selector;

        selectors[selectorIndex++] = IBorrowerOperationsFacet.fetchBalances.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.getGlobalSystemBalances.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.getTCR.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.openTrove.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.removeTroveManager.selector;

        selectors[selectorIndex++] = IBorrowerOperationsFacet.repayDebt.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.setMinNetDebt.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.withdrawColl.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.withdrawDebt.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.checkRecoveryMode.selector;

        selectors[selectorIndex++] = IBorrowerOperationsFacet.getCompositeDebt.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.minNetDebt.selector;
        selectors[selectorIndex++] = IBorrowerOperationsFacet.troveManagersData.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: borrowerOperationsFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildFactoryFacet(address factoryFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(factoryFacet != address(0), "Builder: factoryFacet address must be non-zero");

        uint8 selectorsLength = 6;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = IFactoryFacet.deployNewInstance.selector;
        selectors[selectorIndex++] = IFactoryFacet.troveManagerCount.selector;
        selectors[selectorIndex++] = IFactoryFacet.troveManagers.selector;
        selectors[selectorIndex++] = IFactoryFacet.setTMRewardRate.selector;
        selectors[selectorIndex++] = IFactoryFacet.maxTMRewardRate.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: factoryFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildLiquidationFacet(address liquidationFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(liquidationFacet != address(0), "Builder: factoryFacet address must be non-zero");

        uint8 selectorsLength = 3;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[selectorIndex++] = ILiquidationFacet.liquidate.selector;
        selectors[selectorIndex++] = ILiquidationFacet.liquidateTroves.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: liquidationFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildNexusYieldManagerFacet(address nexusYieldManagerFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(nexusYieldManagerFacet != address(0), "Builder: factoryFacet address must be non-zero");

        uint8 selectorsLength = 26;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = INexusYieldManagerFacet.setAssetConfig.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.sunsetAsset.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.swapIn.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.pause.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.resume.selector;

        selectors[selectorIndex++] = INexusYieldManagerFacet.setPrivileged.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.transferTokenToPrivilegedVault.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.previewSwapOut.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.previewSwapIn.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.swapOutPrivileged.selector;

        selectors[selectorIndex++] = INexusYieldManagerFacet.swapInPrivileged.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.scheduleSwapOut.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.withdraw.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.convertDebtTokenToAssetAmount.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.convertAssetToDebtTokenAmount.selector;

        selectors[selectorIndex++] = INexusYieldManagerFacet.oracle.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.feeIn.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.feeOut.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.debtTokenMintCap.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.dailyDebtTokenMintCap.selector;

        selectors[selectorIndex++] = INexusYieldManagerFacet.debtTokenMinted.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.isUsingOracle.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.swapWaitingPeriod.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.debtTokenDailyMintCapRemain.selector;
        selectors[selectorIndex++] = INexusYieldManagerFacet.pendingWithdrawal.selector;

        selectors[selectorIndex++] = INexusYieldManagerFacet.pendingWithdrawals.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: nexusYieldManagerFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildPriceFeedAggregatorFacet(address priceFeedAggregatorFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(priceFeedAggregatorFacet != address(0), "Builder: factoryFacet address must be non-zero");

        uint8 selectorsLength = 4;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = IPriceFeedAggregatorFacet.fetchPrice.selector;
        selectors[selectorIndex++] = IPriceFeedAggregatorFacet.fetchPriceUnsafe.selector;
        selectors[selectorIndex++] = IPriceFeedAggregatorFacet.setPriceFeed.selector;
        selectors[selectorIndex++] = IPriceFeedAggregatorFacet.oracleRecords.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: priceFeedAggregatorFacet,
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: selectors
        });
    }

    function buildStabilityPoolFacet(address stabilityPoolFacet)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(stabilityPoolFacet != address(0), "Builder: factoryFacet address must be non-zero");

        uint8 selectorsLength = 23;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = IStabilityPoolFacet.claimCollateralGains.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.provideToSP.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.startCollateralSunset.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.withdrawFromSP.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.accountDeposits.selector;

        selectors[selectorIndex++] = IStabilityPoolFacet.collateralGainsByDepositor.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.collateralTokens.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.currentEpoch.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.currentScale.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.depositSnapshots.selector;

        selectors[selectorIndex++] = IStabilityPoolFacet.depositSums.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.epochToScaleToG.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.epochToScaleToSums.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.getCompoundedDebtDeposit.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.getDepositorCollateralGain.selector;

        selectors[selectorIndex++] = IStabilityPoolFacet.getTotalDebtTokenDeposits.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.indexByCollateral.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.claimableReward.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.claimReward.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.setClaimStartTime.selector;

        selectors[selectorIndex++] = IStabilityPoolFacet.isClaimStart.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.rewardRate.selector;
        selectors[selectorIndex++] = IStabilityPoolFacet.setSPRewardRate.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: stabilityPoolFacet, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    function buildInitializer(address initializer)
        public
        pure
        returns (IERC2535DiamondCutInternal.FacetCut memory facetCut)
    {
        require(initializer != address(0), "Builder: initializer address must be non-zero");

        uint8 selectorsLength = 1;
        bytes4[] memory selectors = new bytes4[](selectorsLength);
        uint256 selectorIndex;

        selectors[selectorIndex++] = Initializer.init.selector;

        facetCut = IERC2535DiamondCutInternal.FacetCut({
            target: initializer, action: IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors: selectors
        });
    }

    /// @notice Build path for fetching a field from a transaction in broadcast json file
    /// @dev Only build path from transactions array
    /// @param index Index of the transaction in the transactions array
    /// @param field Field to fetch from the transaction
    /// @return path Path to fetch the field from the transaction
    function buildTxsFilePath(uint32 index, string memory field) external pure returns (string memory path) {
        path = string.concat("$.transactions[", vm.toString(index), "].", field);
    }
}
