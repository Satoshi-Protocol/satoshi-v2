// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {ISolidStateERC20} from "@solidstate/contracts/token/ERC20/ISolidStateERC20.sol";
import {IERC20Metadata} from "@solidstate/contracts/token/ERC20/metadata/IERC20Metadata.sol";
import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IStabilityPoolFacet} from "../interfaces/IStabilityPoolFacet.sol";
import {ISortedTroves} from "../interfaces/ISortedTroves.sol";
import {
    ILiquidationFacet,
    TroveManagerValues,
    LiquidationValues,
    LiquidationTotals
} from "../interfaces/ILiquidationFacet.sol";
import {AppStorage} from "../AppStorage.sol";
import {Config} from "../Config.sol";
import {BorrowerOperationsLib} from "../libs/BorrowerOperationsLib.sol";
import {StabilityPoolLib} from "../libs/StabilityPoolLib.sol";

contract LiquidationFacet is ILiquidationFacet, AccessControlInternal, OwnableInternal {
    using StabilityPoolLib for AppStorage.Layout;
    using BorrowerOperationsLib for AppStorage.Layout;

    // --- Trove Liquidation functions ---

    /**
     * @notice Liquidate a single trove
     *     @dev Reverts if the trove is not active, or cannot be liquidated
     *     @param borrower Borrower address to liquidate
     */
    function liquidate(ITroveManager troveManager, address borrower) external {
        require(troveManager.getTroveStatus(borrower) == 1, "TroveManager: Trove does not exist or is closed");

        address[] memory borrowers = new address[](1);
        borrowers[0] = borrower;
        batchLiquidateTroves(troveManager, borrowers);
    }

    /**
     * @notice Liquidate a sequence of troves
     *     @dev Iterates through troves starting with the lowest ICR
     *     @param maxTrovesToLiquidate The maximum number of troves to liquidate
     *     @param maxICR Maximum ICR to liquidate. Should be set to MCR if the system
     *                   is not in recovery mode, to minimize gas costs for this call.
     */
    function liquidateTroves(ITroveManager troveManager, uint256 maxTrovesToLiquidate, uint256 maxICR) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s.enabledTroveManagers[troveManager], "TroveManager not approved");

        troveManager.updateBalances();

        ISortedTroves sortedTrovesCached = troveManager.sortedTroves();

        LiquidationValues memory singleLiquidation;
        LiquidationTotals memory totals;
        TroveManagerValues memory troveManagerValues;

        uint256 trovesRemaining = maxTrovesToLiquidate;
        uint256 troveCount = troveManager.getTroveOwnersCount();
        troveManagerValues.price = troveManager.fetchPrice();
        troveManagerValues.sunsetting = troveManager.sunsetting();
        troveManagerValues.MCR = troveManager.MCR();
        uint256 debtInStabPool = s._getTotalDebtTokenDeposits();

        while (trovesRemaining > 0 && troveCount > 1) {
            address account = sortedTrovesCached.getLast();
            uint256 ICR = troveManager.getCurrentICR(account, troveManagerValues.price);
            if (ICR > maxICR) {
                // set to 0 to ensure the next if block evaluates false
                trovesRemaining = 0;
                break;
            }
            if (ICR <= Config._100_PCT && _inRecoveryMode()) {
                singleLiquidation = _liquidateWithoutSP(troveManager, account);
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
            } else if (ICR < troveManagerValues.MCR) {
                singleLiquidation =
                    _liquidateNormalMode(troveManager, account, debtInStabPool, troveManagerValues.sunsetting);
                debtInStabPool -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
            } else {
                break;
            } // break if the loop reaches a Trove with ICR >= MCR
            unchecked {
                --trovesRemaining;
                --troveCount;
            }
        }
        if (trovesRemaining > 0 && !troveManagerValues.sunsetting && troveCount > 1) {
            (uint256 entireSystemColl, uint256 entireSystemDebt) = s._getGlobalSystemBalances();
            entireSystemColl -= totals.totalCollToSendToSP * troveManagerValues.price + totals.totalCollGasCompensation;
            entireSystemDebt -= totals.totalDebtToOffset;
            address nextAccount = sortedTrovesCached.getLast();
            ITroveManager _troveManager = troveManager; //stack too deep workaround
            while (trovesRemaining > 0 && troveCount > 1) {
                uint256 ICR = troveManager.getCurrentICR(nextAccount, troveManagerValues.price);
                if (ICR > maxICR) break;
                unchecked {
                    --trovesRemaining;
                }
                address account = nextAccount;
                nextAccount = sortedTrovesCached.getPrev(account);

                uint256 TCR = SatoshiMath._computeCR(entireSystemColl, entireSystemDebt);
                if (TCR >= Config.CCR || ICR >= TCR) break;

                singleLiquidation = _tryLiquidateWithCap(
                    _troveManager, account, debtInStabPool, troveManagerValues.MCR, troveManagerValues.price
                );
                if (singleLiquidation.debtToOffset == 0) continue;
                debtInStabPool -= singleLiquidation.debtToOffset;
                entireSystemColl -=
                    (singleLiquidation.collToSendToSP + singleLiquidation.collSurplus) * troveManagerValues.price;
                entireSystemDebt -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
                unchecked {
                    --troveCount;
                }
            }
        }

        require(totals.totalDebtInSequence > 0, "TroveManager: nothing to liquidate");
        if (totals.totalDebtToOffset > 0 || totals.totalCollToSendToSP > 0) {
            // Move liquidated collateral and Debt to the appropriate pools
            s._offset(troveManager.collateralToken(), totals.totalDebtToOffset, totals.totalCollToSendToSP);
            troveManager.decreaseDebtAndSendCollateral(
                address(this), totals.totalDebtToOffset, totals.totalCollToSendToSP
            );
        }
        troveManager.finalizeLiquidation(
            msg.sender,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            totals.totalCollSurplus,
            totals.totalDebtGasCompensation,
            totals.totalCollGasCompensation
        );

        emit LiquidationTroves(
            address(troveManager),
            totals.totalDebtInSequence,
            totals.totalCollInSequence - totals.totalCollGasCompensation - totals.totalCollSurplus,
            totals.totalCollGasCompensation,
            totals.totalDebtGasCompensation
        );
    }

    /**
     * @notice Liquidate a custom list of troves
     *     @dev Reverts if there is not a single trove that can be liquidated
     *     @param _troveArray List of borrower addresses to liquidate. Troves that were already
     *                        liquidated, or cannot be liquidated, are ignored.
     */
    /*
     * Attempt to liquidate a custom list of troves provided by the caller.
     */
    function batchLiquidateTroves(ITroveManager troveManager, address[] memory _troveArray) public {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s.enabledTroveManagers[troveManager], "TroveManager not approved");
        require(_troveArray.length != 0, "TroveManager: Calldata address array must not be empty");
        troveManager.updateBalances();

        LiquidationValues memory singleLiquidation;
        LiquidationTotals memory totals;
        TroveManagerValues memory troveManagerValues;

        uint256 debtInStabPool = s._getTotalDebtTokenDeposits();
        troveManagerValues.price = troveManager.fetchPrice();
        troveManagerValues.sunsetting = troveManager.sunsetting();
        troveManagerValues.MCR = troveManager.MCR();
        uint256 troveCount = troveManager.getTroveOwnersCount();
        uint256 length = _troveArray.length;
        uint256 troveIter;
        while (troveIter < length && troveCount > 1) {
            // first iteration round, when all liquidated troves have ICR < MCR we do not need to track TCR
            address account = _troveArray[troveIter];

            // closed / non-existent troves return an ICR of type(uint).max and are ignored
            uint256 ICR = troveManager.getCurrentICR(account, troveManagerValues.price);
            if (ICR <= Config._100_PCT && _inRecoveryMode()) {
                singleLiquidation = _liquidateWithoutSP(troveManager, account);
            } else if (ICR < troveManagerValues.MCR) {
                singleLiquidation =
                    _liquidateNormalMode(troveManager, account, debtInStabPool, troveManagerValues.sunsetting);
                debtInStabPool -= singleLiquidation.debtToOffset;
            } else {
                // As soon as we find a trove with ICR >= MCR we need to start tracking the global TCR with the next loop
                break;
            }
            _applyLiquidationValuesToTotals(totals, singleLiquidation);
            unchecked {
                ++troveIter;
                --troveCount;
            }
        }

        if (troveIter < length && troveCount > 1) {
            // second iteration round, if we receive a trove with ICR > MCR and need to track TCR
            (uint256 entireSystemColl, uint256 entireSystemDebt) = s._getGlobalSystemBalances();
            entireSystemColl -= totals.totalCollToSendToSP * troveManagerValues.price + totals.totalCollGasCompensation;
            entireSystemDebt -= totals.totalDebtToOffset;
            while (troveIter < length && troveCount > 1) {
                address account = _troveArray[troveIter];
                uint256 ICR = troveManager.getCurrentICR(account, troveManagerValues.price);
                unchecked {
                    ++troveIter;
                }
                if (ICR <= Config._100_PCT && _inRecoveryMode()) {
                    singleLiquidation = _liquidateWithoutSP(troveManager, account);
                } else if (ICR < troveManagerValues.MCR) {
                    singleLiquidation =
                        _liquidateNormalMode(troveManager, account, debtInStabPool, troveManagerValues.sunsetting);
                } else {
                    if (troveManagerValues.sunsetting) continue;
                    uint256 TCR = SatoshiMath._computeCR(entireSystemColl, entireSystemDebt);
                    if (TCR >= Config.CCR || ICR >= TCR) continue;
                    singleLiquidation = _tryLiquidateWithCap(
                        troveManager, account, debtInStabPool, troveManagerValues.MCR, troveManagerValues.price
                    );
                    if (singleLiquidation.debtToOffset == 0) continue;
                }

                debtInStabPool -= singleLiquidation.debtToOffset;
                entireSystemColl -= (singleLiquidation.collToSendToSP + singleLiquidation.collSurplus)
                    * troveManagerValues.price + singleLiquidation.collGasCompensation;
                entireSystemDebt -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
                unchecked {
                    --troveCount;
                }
            }
        }

        require(totals.totalDebtInSequence > 0, "TroveManager: nothing to liquidate");

        if (totals.totalDebtToOffset > 0 || totals.totalCollToSendToSP > 0) {
            // Move liquidated collateral and Debt to the appropriate pools
            s._offset(troveManager.collateralToken(), totals.totalDebtToOffset, totals.totalCollToSendToSP);
            troveManager.decreaseDebtAndSendCollateral(
                address(this), totals.totalDebtToOffset, totals.totalCollToSendToSP
            );
        }
        troveManager.finalizeLiquidation(
            msg.sender,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            totals.totalCollSurplus,
            totals.totalDebtGasCompensation,
            totals.totalCollGasCompensation
        );

        emit LiquidationTroves(
            address(troveManager),
            totals.totalDebtInSequence,
            totals.totalCollInSequence - totals.totalCollGasCompensation - totals.totalCollSurplus,
            totals.totalCollGasCompensation,
            totals.totalDebtGasCompensation
        );
    }

    /**
     * @dev Perform a "normal" liquidation, where ICR < MCR. The trove
     *          is liquidated as much as possible using the stability pool. Any
     *          remaining debt and collateral are redistributed between active troves.
     */
    function _liquidateNormalMode(
        ITroveManager troveManager,
        address _borrower,
        uint256 _debtInStabPool,
        bool sunsetting
    ) internal returns (LiquidationValues memory singleLiquidation) {
        uint256 pendingDebtReward;
        uint256 pendingCollReward;

        (singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, pendingDebtReward, pendingCollReward) =
            troveManager.getEntireDebtAndColl(_borrower);

        troveManager.movePendingTroveRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.collGasCompensation = SatoshiMath._getCollGasCompensation(singleLiquidation.entireTroveColl);
        singleLiquidation.debtGasCompensation = Config.DEBT_GAS_COMPENSATION;
        uint256 collToLiquidate = singleLiquidation.entireTroveColl - singleLiquidation.collGasCompensation;

        (
            singleLiquidation.debtToOffset,
            singleLiquidation.collToSendToSP,
            singleLiquidation.debtToRedistribute,
            singleLiquidation.collToRedistribute
        ) = _getOffsetAndRedistributionVals(
            singleLiquidation.entireTroveDebt, collToLiquidate, _debtInStabPool, sunsetting
        );

        troveManager.closeTroveByLiquidation(_borrower);

        return singleLiquidation;
    }

    /**
     * @dev Attempt to liquidate a single trove in recovery mode.
     *          If MCR <= ICR < current TCR (accounting for the preceding liquidations in the current sequence)
     *          and there is Debt in the Stability Pool, only offset, with no redistribution,
     *          but at a capped rate of 1.1 and only if the whole debt can be liquidated.
     *          The remainder due to the capped rate will be claimable as collateral surplus.
     */
    function _tryLiquidateWithCap(
        ITroveManager troveManager,
        address _borrower,
        uint256 _debtInStabPool,
        uint256 _MCR,
        uint256 _price
    ) internal returns (LiquidationValues memory singleLiquidation) {
        uint256 entireTroveDebt;
        uint256 entireTroveColl;
        uint256 pendingDebtReward;
        uint256 pendingCollReward;

        (entireTroveDebt, entireTroveColl, pendingDebtReward, pendingCollReward) =
            troveManager.getEntireDebtAndColl(_borrower);

        if (entireTroveDebt > _debtInStabPool) {
            // do not liquidate if the entire trove cannot be liquidated via SP
            return singleLiquidation;
        }

        troveManager.movePendingTroveRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.entireTroveDebt = entireTroveDebt;
        singleLiquidation.entireTroveColl = entireTroveColl;
        uint256 collToOffset = SatoshiMath._getOriginalCollateralAmount(
            (entireTroveDebt * _MCR) / _price, IERC20Metadata(address(troveManager.collateralToken())).decimals()
        );

        singleLiquidation.collGasCompensation = SatoshiMath._getCollGasCompensation(collToOffset);
        singleLiquidation.debtGasCompensation = Config.DEBT_GAS_COMPENSATION;

        singleLiquidation.debtToOffset = entireTroveDebt;
        singleLiquidation.collToSendToSP = collToOffset - singleLiquidation.collGasCompensation;

        troveManager.closeTroveByLiquidation(_borrower);

        uint256 collSurplus = entireTroveColl - collToOffset;
        if (collSurplus > 0) {
            singleLiquidation.collSurplus = collSurplus;
            troveManager.addCollateralSurplus(_borrower, collSurplus);
        }

        return singleLiquidation;
    }

    /**
     * @dev Liquidate a trove without using the stability pool. All debt and collateral
     *          are distributed porportionally between the remaining active troves.
     */
    function _liquidateWithoutSP(ITroveManager troveManager, address _borrower)
        internal
        returns (LiquidationValues memory singleLiquidation)
    {
        uint256 pendingDebtReward;
        uint256 pendingCollReward;

        (singleLiquidation.entireTroveDebt, singleLiquidation.entireTroveColl, pendingDebtReward, pendingCollReward) =
            troveManager.getEntireDebtAndColl(_borrower);

        singleLiquidation.collGasCompensation = SatoshiMath._getCollGasCompensation(singleLiquidation.entireTroveColl);
        singleLiquidation.debtGasCompensation = Config.DEBT_GAS_COMPENSATION;
        troveManager.movePendingTroveRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.debtToOffset = 0;
        singleLiquidation.collToSendToSP = 0;
        singleLiquidation.debtToRedistribute = singleLiquidation.entireTroveDebt;
        singleLiquidation.collToRedistribute = singleLiquidation.entireTroveColl - singleLiquidation.collGasCompensation;

        troveManager.closeTroveByLiquidation(_borrower);

        return singleLiquidation;
    }

    /* In a full liquidation, returns the values for a trove's coll and debt to be offset, and coll and debt to be
     * redistributed to active troves.
     */
    function _getOffsetAndRedistributionVals(uint256 _debt, uint256 _coll, uint256 _debtInStabPool, bool sunsetting)
        internal
        pure
        returns (uint256 debtToOffset, uint256 collToSendToSP, uint256 debtToRedistribute, uint256 collToRedistribute)
    {
        if (_debtInStabPool > 0 && !sunsetting) {
            /*
             * Offset as much debt & collateral as possible against the Stability Pool, and redistribute the remainder
             * between all active troves.
             *
             *  If the trove's debt is larger than the deposited Debt in the Stability Pool:
             *
             *  - Offset an amount of the trove's debt equal to the Debt in the Stability Pool
             *  - Send a fraction of the trove's collateral to the Stability Pool, equal to the fraction of its offset debt
             *
             */
            debtToOffset = SatoshiMath._min(_debt, _debtInStabPool);
            collToSendToSP = (_coll * debtToOffset) / _debt;
            debtToRedistribute = _debt - debtToOffset;
            collToRedistribute = _coll - collToSendToSP;
        } else {
            debtToOffset = 0;
            collToSendToSP = 0;
            debtToRedistribute = _debt;
            collToRedistribute = _coll;
        }
    }

    /**
     * @dev Adds values from `singleLiquidation` to `totals`
     *          Calling this function mutates `totals`, the change is done in-place
     *          to avoid needless expansion of memory
     */
    function _applyLiquidationValuesToTotals(
        LiquidationTotals memory totals,
        LiquidationValues memory singleLiquidation
    ) internal pure {
        // Tally all the values with their respective running totals
        totals.totalCollGasCompensation = totals.totalCollGasCompensation + singleLiquidation.collGasCompensation;
        totals.totalDebtGasCompensation = totals.totalDebtGasCompensation + singleLiquidation.debtGasCompensation;
        totals.totalDebtInSequence = totals.totalDebtInSequence + singleLiquidation.entireTroveDebt;
        totals.totalCollInSequence = totals.totalCollInSequence + singleLiquidation.entireTroveColl;
        totals.totalDebtToOffset = totals.totalDebtToOffset + singleLiquidation.debtToOffset;
        totals.totalCollToSendToSP = totals.totalCollToSendToSP + singleLiquidation.collToSendToSP;
        totals.totalDebtToRedistribute = totals.totalDebtToRedistribute + singleLiquidation.debtToRedistribute;
        totals.totalCollToRedistribute = totals.totalCollToRedistribute + singleLiquidation.collToRedistribute;
        totals.totalCollSurplus = totals.totalCollSurplus + singleLiquidation.collSurplus;
    }

    function _inRecoveryMode() internal returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        (uint256 _entireSystemColl, uint256 _entireSystemDebt) = s._getGlobalSystemBalances();
        uint256 TCR = SatoshiMath._computeCR(_entireSystemColl, _entireSystemDebt);
        return BorrowerOperationsLib._checkRecoveryMode(TCR);
    }
}
