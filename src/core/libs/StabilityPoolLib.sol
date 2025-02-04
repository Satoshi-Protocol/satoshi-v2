// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SatoshiMath } from "../../library/SatoshiMath.sol";
import { AppStorage } from "../AppStorage.sol";

import { Config } from "../Config.sol";
import { Snapshots } from "../interfaces/IStabilityPoolFacet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library StabilityPoolLib {
    event G_Updated(uint256 _G, uint128 _epoch, uint128 _scale);
    event S_Updated(uint256 idx, uint256 _S, uint128 _epoch, uint128 _scale);
    event ScaleUpdated(uint128 _currentScale);
    event EpochUpdated(uint128 _currentEpoch);
    event P_Updated(uint256 _P);
    event StabilityPoolDebtBalanceUpdated(uint256 _newBalance);

    /*
     * Cancels out the specified debt against the Debt contained in the Stability Pool (as far as possible)
     */

    function _offset(
        AppStorage.Layout storage s,
        IERC20 collateral,
        uint256 _debtToOffset,
        uint256 _collToAdd
    )
        internal
    {
        uint256 idx = s.indexByCollateral[collateral];
        idx -= 1;

        uint256 totalDebt = s.totalDebtTokenDeposits; // cached to save an SLOAD
        if (totalDebt == 0 || _debtToOffset == 0) {
            return;
        }

        _triggerOSHIIssuance(s);

        uint8 _decimals = IERC20Metadata(address(collateral)).decimals();
        uint256 scaledCollToAdd = SatoshiMath._getScaledCollateralAmount(_collToAdd, _decimals);

        (uint256 collateralGainPerUnitStaked, uint256 debtLossPerUnitStaked) =
            _computeRewardsPerUnitStaked(s, scaledCollToAdd, _debtToOffset, totalDebt, idx);

        _updateRewardSumAndProduct(s, collateralGainPerUnitStaked, debtLossPerUnitStaked, idx); // updates S and P

        // Cancel the liquidated Debt debt with the Debt in the stability pool
        _decreaseDebt(s, _debtToOffset);
    }

    // --- OSHI issuance functions ---
    function _triggerOSHIIssuance(AppStorage.Layout storage s) internal {
        uint256 OSHIIssuance = _OSHIIssuance(s);
        s.communityIssuance.collectAllocatedTokens(OSHIIssuance);
        _updateG(s, OSHIIssuance);
        s.lastUpdate = uint32(block.timestamp);
    }

    function _updateG(AppStorage.Layout storage s, uint256 OSHIIssuance) internal {
        uint256 totalDebt = s.totalDebtTokenDeposits; // cached to save an SLOAD
        /*
         * When total deposits is 0, G is not updated. In this case, the OSHI issued can not be obtained by later
         * depositors - it is missed out on, and remains in the balanceof the Treasury contract.
         *
         */
        if (totalDebt == 0 || OSHIIssuance == 0) {
            return;
        }

        uint256 oshiPerUnitStaked;
        oshiPerUnitStaked = _computeOSHIPerUnitStaked(s, OSHIIssuance, totalDebt);
        uint128 currentEpochCached = s.currentEpoch;
        uint128 currentScaleCached = s.currentScale;
        uint256 marginalOSHIGain = oshiPerUnitStaked * s.P;
        uint256 newG = s.epochToScaleToG[currentEpochCached][currentScaleCached] + marginalOSHIGain;
        s.epochToScaleToG[currentEpochCached][currentScaleCached] = newG;

        emit G_Updated(newG, currentEpochCached, currentScaleCached);
    }

    // --- Offset helper functions ---

    function _computeRewardsPerUnitStaked(
        AppStorage.Layout storage s,
        uint256 _collToAdd,
        uint256 _debtToOffset,
        uint256 _totalDebtTokenDeposits,
        uint256 idx
    )
        internal
        returns (uint256 collateralGainPerUnitStaked, uint256 debtLossPerUnitStaked)
    {
        /*
         * Compute the Debt and collateral rewards. Uses a "feedback" error correction, to keep
         * the cumulative error in the P and S state variables low:
         *
         * 1) Form numerators which compensate for the floor division errors that occurred the last time this
         * function was called.
         * 2) Calculate "per-unit-staked" ratios.
         * 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
         * 4) Store these errors for use in the next correction when this function is called.
         * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
         */
        uint256 collateralNumerator = (_collToAdd * SatoshiMath.DECIMAL_PRECISION) + s.lastCollateralError_Offset[idx];

        if (_debtToOffset == _totalDebtTokenDeposits) {
            debtLossPerUnitStaked = SatoshiMath.DECIMAL_PRECISION; // When the Pool depletes to 0, so does each deposit
            s.lastDebtLossError_Offset = 0;
        } else {
            uint256 debtLossNumerator = (_debtToOffset * SatoshiMath.DECIMAL_PRECISION) - s.lastDebtLossError_Offset;
            /*
             * Add 1 to make error in quotient positive. We want "slightly too much" Debt loss,
             * which ensures the error in any given compoundedDebtDeposit favors the Stability Pool.
             */
            debtLossPerUnitStaked = (debtLossNumerator / _totalDebtTokenDeposits) + 1;
            s.lastDebtLossError_Offset = (debtLossPerUnitStaked * _totalDebtTokenDeposits) - debtLossNumerator;
        }

        collateralGainPerUnitStaked = collateralNumerator / _totalDebtTokenDeposits;
        s.lastCollateralError_Offset[idx] =
            collateralNumerator - (collateralGainPerUnitStaked * _totalDebtTokenDeposits);

        return (collateralGainPerUnitStaked, debtLossPerUnitStaked);
    }

    // Update the Stability Pool reward sum S and product P
    function _updateRewardSumAndProduct(
        AppStorage.Layout storage s,
        uint256 _collateralGainPerUnitStaked,
        uint256 _debtLossPerUnitStaked,
        uint256 idx
    )
        internal
    {
        uint256 currentP = s.P;
        uint256 newP;

        /*
         * The newProductFactor is the factor by which to change all deposits, due to the depletion of Stability Pool Debt in the liquidation.
         * We make the product factor 0 if there was a pool-emptying. Otherwise, it is (1 - DebtLossPerUnitStaked)
         */
        uint256 newProductFactor = uint256(SatoshiMath.DECIMAL_PRECISION) - _debtLossPerUnitStaked;

        uint128 currentScaleCached = s.currentScale;
        uint128 currentEpochCached = s.currentEpoch;
        uint256 currentS = s.epochToScaleToSums[currentEpochCached][currentScaleCached][idx];

        /*
         * Calculate the new S first, before we update P.
         * The collateral gain for any given depositor from a liquidation depends on the value of their deposit
         * (and the value of totalDeposits) prior to the Stability being depleted by the debt in the liquidation.
         *
         * Since S corresponds to collateral gain, and P to deposit loss, we update S first.
         */
        uint256 marginalCollateralGain = _collateralGainPerUnitStaked * currentP;
        uint256 newS = currentS + marginalCollateralGain;
        s.epochToScaleToSums[currentEpochCached][currentScaleCached][idx] = newS;
        emit S_Updated(idx, newS, currentEpochCached, currentScaleCached);

        // If the Stability Pool was emptied, increment the epoch, and reset the scale and product P
        if (newProductFactor == 0) {
            s.currentEpoch = currentEpochCached + 1;
            emit EpochUpdated(s.currentEpoch);
            s.currentScale = 0;
            emit ScaleUpdated(s.currentScale);
            newP = SatoshiMath.DECIMAL_PRECISION;

            // If multiplying P by a non-zero product factor would reduce P below the scale boundary, increment the scale
        } else if ((currentP * newProductFactor) / SatoshiMath.DECIMAL_PRECISION < Config.SCALE_FACTOR) {
            newP = (currentP * newProductFactor * Config.SCALE_FACTOR) / SatoshiMath.DECIMAL_PRECISION;
            s.currentScale = currentScaleCached + 1;
            emit ScaleUpdated(s.currentScale);
        } else {
            newP = (currentP * newProductFactor) / SatoshiMath.DECIMAL_PRECISION;
        }

        require(newP > 0, "NewP");
        s.P = newP;
        emit P_Updated(newP);
    }

    function _decreaseDebt(AppStorage.Layout storage s, uint256 _amount) internal {
        uint256 newTotalDebtTokenDeposits = s.totalDebtTokenDeposits - _amount;
        s.totalDebtTokenDeposits = newTotalDebtTokenDeposits;
        emit StabilityPoolDebtBalanceUpdated(newTotalDebtTokenDeposits);
    }

    function _computeOSHIPerUnitStaked(
        AppStorage.Layout storage s,
        uint256 OSHIIssuance,
        uint256 _totalDebtTokenDeposits
    )
        internal
        returns (uint256)
    {
        /*
        * Calculate the OSHI-per-unit staked.  Division uses a "feedback" error correction, to keep the
        * cumulative error low in the running total G:
        *
        * 1) Form a numerator which compensates for the floor division error that occurred the last time this
        * function was called.
        * 2) Calculate "per-unit-staked" ratio.
        * 3) Multiply the ratio back by its denominator, to reveal the current floor division error.
        * 4) Store this error for use in the next correction when this function is called.
        * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
        */
        uint256 OSHINumerator = (OSHIIssuance * SatoshiMath.DECIMAL_PRECISION) + s.lastOSHIError;

        uint256 OSHIPerUnitStaked = OSHINumerator / _totalDebtTokenDeposits;
        s.lastOSHIError = OSHINumerator - (OSHIPerUnitStaked * _totalDebtTokenDeposits);

        return OSHIPerUnitStaked;
    }

    function _OSHIIssuance(AppStorage.Layout storage s) internal view returns (uint256) {
        uint256 duration = block.timestamp - s.lastUpdate;
        uint256 releasedToken = duration * s.spRewardRate;
        uint256 allocatedToken = s.communityIssuance.allocated(address(this));
        // check the allocated token in community issuance
        if (releasedToken > allocatedToken) {
            releasedToken = allocatedToken;
        }
        return releasedToken;
    }

    function _getCompoundedDebtDeposit(
        AppStorage.Layout storage s,
        address _depositor
    )
        internal
        view
        returns (uint256)
    {
        uint256 initialDeposit = s.accountDeposits[_depositor].amount;
        if (initialDeposit == 0) {
            return 0;
        }

        Snapshots memory snapshots = s.depositSnapshots[_depositor];

        uint256 compoundedDeposit = _getCompoundedStakeFromSnapshots(s, initialDeposit, snapshots);
        return compoundedDeposit;
    }

    // Internal function, used to calculcate compounded deposits and compounded front end stakes.
    function _getCompoundedStakeFromSnapshots(
        AppStorage.Layout storage s,
        uint256 initialStake,
        Snapshots memory snapshots
    )
        internal
        view
        returns (uint256)
    {
        uint256 snapshot_P = snapshots.P;
        uint128 scaleSnapshot = snapshots.scale;
        uint128 epochSnapshot = snapshots.epoch;

        // If stake was made before a pool-emptying event, then it has been fully cancelled with debt -- so, return 0
        if (epochSnapshot < s.currentEpoch) {
            return 0;
        }

        uint256 compoundedStake;
        uint128 scaleDiff = s.currentScale - scaleSnapshot;

        /* Compute the compounded stake. If a scale change in P was made during the stake's lifetime,
         * account for it. If more than one scale change was made, then the stake has decreased by a factor of
         * at least 1e-9 -- so return 0.
         */
        if (scaleDiff == 0) {
            compoundedStake = (initialStake * s.P) / snapshot_P;
        } else if (scaleDiff == 1) {
            compoundedStake = (initialStake * s.P) / snapshot_P / Config.SCALE_FACTOR;
        } else {
            // if scaleDiff >= 2
            compoundedStake = 0;
        }

        /*
         * If compounded deposit is less than a billionth of the initial deposit, return 0.
         *
         * NOTE: originally, this line was in place to stop rounding errors making the deposit too large. However, the error
         * corrections should ensure the error in P "favors the Pool", i.e. any given compounded deposit should slightly less
         * than it's theoretical value.
         *
         * Thus it's unclear whether this line is still really needed.
         */
        if (compoundedStake < initialStake / 1e9) {
            return 0;
        }

        return compoundedStake;
    }

    function _getOSHIGainFromSnapshots(
        AppStorage.Layout storage s,
        uint256 initialStake,
        Snapshots memory snapshots
    )
        internal
        view
        returns (uint256)
    {
        /*
         * Grab the sum 'G' from the epoch at which the stake was made. The OSHI gain may span up to one scale change.
         * If it does, the second portion of the OSHI gain is scaled by 1e9.
         * If the gain spans no scale change, the second portion will be 0.
         */
        uint128 epochSnapshot = snapshots.epoch;
        uint128 scaleSnapshot = snapshots.scale;
        uint256 G_Snapshot = snapshots.G;
        uint256 P_Snapshot = snapshots.P;

        uint256 firstPortion = s.epochToScaleToG[epochSnapshot][scaleSnapshot] - G_Snapshot;
        uint256 secondPortion = s.epochToScaleToG[epochSnapshot][scaleSnapshot + 1] / Config.SCALE_FACTOR;

        uint256 OSHIGain = (initialStake * (firstPortion + secondPortion)) / P_Snapshot / SatoshiMath.DECIMAL_PRECISION;

        return OSHIGain;
    }

    function _getTotalDebtTokenDeposits(AppStorage.Layout storage s) internal view returns (uint256) {
        return s.totalDebtTokenDeposits;
    }

    function _isClaimStart(AppStorage.Layout storage s) internal view returns (bool) {
        return s.claimStartTime <= uint32(block.timestamp);
    }
}
