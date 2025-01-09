// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {
    IStabilityPoolFacet, AccountDeposit, Snapshots, SunsetIndex, Queue
} from "../interfaces/IStabilityPoolFacet.sol";
import {Config} from "../Config.sol";
import {AppStorage} from "../AppStorage.sol";
import {StabilityPoolLib} from "../libs/StabilityPoolLib.sol";

contract StabilityPoolFacet is IStabilityPoolFacet, AccessControlInternal {
    using SafeERC20 for IERC20;
    using StabilityPoolLib for AppStorage.Layout;

    function setSPRewardRate(uint128 _newRewardRate) external onlyRole(Config.OWNER_ROLE) {
        require(_newRewardRate <= Config.SP_MAX_REWARD_RATE, "StabilityPool: Reward rate too high");
        AppStorage.Layout storage s = AppStorage.layout();
        s._triggerOSHIIssuance();
        s.spRewardRate = _newRewardRate;
        emit RewardRateUpdated(_newRewardRate);
    }

    /**
     * @notice Starts sunsetting a collateral
     *         During sunsetting liquidated collateral handoff to the SP will revert
     *     @dev IMPORTANT: When sunsetting a collateral, `TroveManager.startSunset`
     *                     should be called on all TM linked to that collateral
     *     @param collateral Collateral to sunset
     */
    function startCollateralSunset(IERC20 collateral) external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s.indexByCollateral[collateral] > 0, "Collateral already sunsetting");
        s.sunsetIndexes[s.queue.nextSunsetIndexKey++] =
            SunsetIndex(uint128(s.indexByCollateral[collateral] - 1), uint128(block.timestamp + Config.SUNSET_DURATION));
        delete s.indexByCollateral[collateral]; //This will prevent calls to the SP in case of liquidations
        emit CollateralSunset(address(collateral));
    }

    function getTotalDebtTokenDeposits() external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s._getTotalDebtTokenDeposits();
    }

    // --- External Depositor Functions ---

    /*  provideToSP():
     *
     * - Triggers a Satoshi issuance, based on time passed since the last issuance. The Satoshi issuance is shared between *all* depositors and front ends
     * - Tags the deposit with the provided front end tag param, if it's a new deposit
     * - Sends depositor's accumulated gains (Satoshi, collateral) to depositor
     * - Sends the tagged front end's accumulated Satoshi gains to the tagged front end
     * - Increases deposit and tagged front end's stake, and takes new snapshots for each.
     */
    function provideToSP(uint256 _amount) external {
        AppStorage.Layout storage s = AppStorage.layout();
        require(!s.paused, "Deposits are paused");
        require(_amount > 0, "StabilityPool: Amount must be non-zero");

        s._triggerOSHIIssuance();

        _accrueDepositorCollateralGain(s, msg.sender);

        uint256 compoundedDebtDeposit = s._getCompoundedDebtDeposit(msg.sender);

        _accrueRewards(s, msg.sender);

        s.debtToken.sendToXApp(msg.sender, _amount);
        uint256 newTotalDebtTokenDeposits = s.totalDebtTokenDeposits + _amount;
        s.totalDebtTokenDeposits = newTotalDebtTokenDeposits;
        emit StabilityPoolLib.StabilityPoolDebtBalanceUpdated(newTotalDebtTokenDeposits);

        uint256 newDeposit = compoundedDebtDeposit + _amount;
        s.accountDeposits[msg.sender] =
            AccountDeposit({amount: uint128(newDeposit), timestamp: uint128(block.timestamp)});

        _updateSnapshots(s, msg.sender, newDeposit);
        emit UserDepositChanged(msg.sender, newDeposit);
    }

    /*  withdrawFromSP():
     *
     * - Triggers a Satoshi issuance, based on time passed since the last issuance. The Satoshi issuance is shared between *all* depositors and front ends
     * - Removes the deposit's front end tag if it is a full withdrawal
     * - Sends all depositor's accumulated gains (Satoshi, collateral) to depositor
     * - Sends the tagged front end's accumulated Satoshi gains to the tagged front end
     * - Decreases deposit and tagged front end's stake, and takes new snapshots for each.
     *
     * If _amount > userDeposit, the user withdraws all of their compounded deposit.
     */
    function withdrawFromSP(uint256 _amount) external {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 initialDeposit = s.accountDeposits[msg.sender].amount;
        uint128 depositTimestamp = s.accountDeposits[msg.sender].timestamp;
        require(initialDeposit > 0, "StabilityPool: User must have a non-zero deposit");
        require(depositTimestamp < block.timestamp, "!Deposit and withdraw same block");

        s._triggerOSHIIssuance();

        _accrueDepositorCollateralGain(s, msg.sender);

        uint256 compoundedDebtDeposit = s._getCompoundedDebtDeposit(msg.sender);
        uint256 debtToWithdraw = SatoshiMath._min(_amount, compoundedDebtDeposit);

        _accrueRewards(s, msg.sender);

        if (debtToWithdraw > 0) {
            s.debtToken.returnFromPool(address(this), msg.sender, debtToWithdraw);
            s._decreaseDebt(debtToWithdraw);
        }

        // Update deposit
        uint256 newDeposit = compoundedDebtDeposit - debtToWithdraw;
        s.accountDeposits[msg.sender] = AccountDeposit({amount: uint128(newDeposit), timestamp: depositTimestamp});

        _updateSnapshots(s, msg.sender, newDeposit);
        emit UserDepositChanged(msg.sender, newDeposit);
    }

    // --- Liquidation functions ---

    // --- Reward calculator functions for depositor ---

    /* Calculates the collateral gain earned by the deposit since its last snapshots were taken.
     * Given by the formula:  E = d0 * (S - S(0))/P(0)
     * where S(0) and P(0) are the depositor's snapshots of the sum S and product P, respectively.
     * d0 is the last recorded deposit value.
     */
    function getDepositorCollateralGain(address _depositor) external view returns (uint256[] memory collateralGains) {
        AppStorage.Layout storage s = AppStorage.layout();
        collateralGains = new uint256[](s.collateralTokens.length);
        uint80[256] storage depositorGains = s.collateralGainsByDepositor[_depositor];
        for (uint256 i = 0; i < collateralGains.length; i++) {
            collateralGains[i] = depositorGains[i];
        }

        uint256 P_Snapshot = s.depositSnapshots[_depositor].P;
        if (P_Snapshot == 0) return collateralGains;
        uint256 initialDeposit = s.accountDeposits[_depositor].amount;
        uint128 epochSnapshot = s.depositSnapshots[_depositor].epoch;
        uint128 scaleSnapshot = s.depositSnapshots[_depositor].scale;
        uint256[256] storage sums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot];
        uint256[256] storage nextSums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
        uint256[256] storage depSums = s.depositSums[_depositor];

        for (uint256 i = 0; i < collateralGains.length; i++) {
            if (sums[i] == 0) continue; // Collateral was overwritten or not gains
            uint256 firstPortion = sums[i] - depSums[i];
            uint256 secondPortion = nextSums[i] / Config.SCALE_FACTOR;
            uint8 _decimals = IERC20Metadata(address(s.collateralTokens[i])).decimals();
            collateralGains[i] += initialDeposit
                * SatoshiMath._getOriginalCollateralAmount(firstPortion + secondPortion, _decimals) / P_Snapshot
                / SatoshiMath.DECIMAL_PRECISION;
        }
        return collateralGains;
    }

    function _accrueDepositorCollateralGain(AppStorage.Layout storage s, address _depositor)
        private
        returns (bool hasGains)
    {
        uint80[256] storage depositorGains = s.collateralGainsByDepositor[_depositor];
        uint256 collaterals = s.collateralTokens.length;
        uint256 initialDeposit = s.accountDeposits[_depositor].amount;
        hasGains = false;
        if (initialDeposit == 0) {
            return hasGains;
        }

        uint128 epochSnapshot = s.depositSnapshots[_depositor].epoch;
        uint128 scaleSnapshot = s.depositSnapshots[_depositor].scale;
        uint256 P_Snapshot = s.depositSnapshots[_depositor].P;

        uint256[256] storage sums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot];
        uint256[256] storage nextSums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
        uint256[256] storage depSums = s.depositSums[_depositor];

        for (uint256 i = 0; i < collaterals; i++) {
            if (sums[i] == 0) continue; // Collateral was overwritten or not gains
            hasGains = true;
            uint256 firstPortion = sums[i] - depSums[i];
            uint256 secondPortion = nextSums[i] / Config.SCALE_FACTOR;
            uint8 _decimals = IERC20Metadata(address(s.collateralTokens[i])).decimals();
            depositorGains[i] += uint80(
                (
                    initialDeposit * SatoshiMath._getOriginalCollateralAmount(firstPortion + secondPortion, _decimals)
                        / P_Snapshot / SatoshiMath.DECIMAL_PRECISION
                )
            );
        }
        return (hasGains);
    }

    /*
     * Calculate the OSHI gain earned by a deposit since its last snapshots were taken.
     * Given by the formula:  OSHI = d0 * (G - G(0))/P(0)
     * where G(0) and P(0) are the depositor's snapshots of the sum G and product P, respectively.
     * d0 is the last recorded deposit value.
     */
    function claimableReward(address _depositor) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 totalDebt = s.totalDebtTokenDeposits;
        uint256 initialDeposit = s.accountDeposits[_depositor].amount;

        if (totalDebt == 0 || initialDeposit == 0) {
            return s.storedPendingReward[_depositor] + _claimableReward(s, _depositor);
        }

        Snapshots memory snapshots = s.depositSnapshots[_depositor];
        uint128 epochSnapshot = snapshots.epoch;
        uint128 scaleSnapshot = snapshots.scale;
        uint256 oshiNumerator = (s._OSHIIssuance() * SatoshiMath.DECIMAL_PRECISION) + s.lastOSHIError;
        uint256 oshiPerUnitStaked = oshiNumerator / totalDebt;
        uint256 marginalOSHIGain = (epochSnapshot == s.currentEpoch) ? oshiPerUnitStaked * s.P : 0;
        uint256 firstPortion;
        uint256 secondPortion;

        if (scaleSnapshot == s.currentScale) {
            firstPortion = s.epochToScaleToG[epochSnapshot][scaleSnapshot] - snapshots.G + marginalOSHIGain;
            secondPortion = s.epochToScaleToG[epochSnapshot][scaleSnapshot + 1] / Config.SCALE_FACTOR;
        } else {
            firstPortion = s.epochToScaleToG[epochSnapshot][scaleSnapshot] - snapshots.G;
            secondPortion =
                (s.epochToScaleToG[epochSnapshot][scaleSnapshot + 1] + marginalOSHIGain) / Config.SCALE_FACTOR;
        }

        return s.storedPendingReward[_depositor]
            + (initialDeposit * (firstPortion + secondPortion)) / snapshots.P / SatoshiMath.DECIMAL_PRECISION;
    }

    function _claimableReward(AppStorage.Layout storage s, address _depositor) private view returns (uint256) {
        uint256 initialDeposit = s.accountDeposits[_depositor].amount;
        if (initialDeposit == 0) {
            return 0;
        }

        Snapshots memory snapshots = s.depositSnapshots[_depositor];

        return s._getOSHIGainFromSnapshots(initialDeposit, snapshots);
    }

    // --- Compounded deposit ---

    /*
     * Return the user's compounded deposit. Given by the formula:  d = d0 * P/P(0)
     * where P(0) is the depositor's snapshot of the product P, taken when they last updated their deposit.
     */
    function getCompoundedDebtDeposit(address _depositor) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s._getCompoundedDebtDeposit(_depositor);
    }

    // --- Sender functions for Debt deposit, collateral gains and Satoshi gains ---
    function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) external virtual {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 compoundedDebtDeposit = s._getCompoundedDebtDeposit(msg.sender);
        uint128 depositTimestamp = s.accountDeposits[msg.sender].timestamp;
        _accrueDepositorCollateralGain(s, msg.sender);

        uint256 loopEnd = collateralIndexes.length;
        uint256[] memory collateralGains = new uint256[](s.collateralTokens.length);

        uint80[256] storage depositorGains = s.collateralGainsByDepositor[msg.sender];
        for (uint256 i; i < loopEnd;) {
            uint256 collateralIndex = collateralIndexes[i];
            uint256 gains = depositorGains[collateralIndex];
            if (gains > 0) {
                collateralGains[collateralIndex] = gains;
                depositorGains[collateralIndex] = 0;
                s.collateralTokens[collateralIndex].safeTransfer(recipient, gains);
            }
            unchecked {
                ++i;
            }
        }
        s.accountDeposits[msg.sender] =
            AccountDeposit({amount: uint128(compoundedDebtDeposit), timestamp: depositTimestamp});
        _updateSnapshots(s, msg.sender, compoundedDebtDeposit);
        emit CollateralGainWithdrawn(msg.sender, collateralGains);
    }

    // --- Stability Pool Deposit Functionality ---

    function _updateSnapshots(AppStorage.Layout storage s, address _depositor, uint256 _newValue) internal {
        uint256 length;
        if (_newValue == 0) {
            delete s.depositSnapshots[_depositor];

            length = s.collateralTokens.length;
            for (uint256 i = 0; i < length; i++) {
                s.depositSums[_depositor][i] = 0;
            }
            emit DepositSnapshotUpdated(_depositor, 0, 0);
            return;
        }
        uint128 currentScaleCached = s.currentScale;
        uint128 currentEpochCached = s.currentEpoch;
        uint256 currentP = s.P;

        // Get S and G for the current epoch and current scale
        uint256[256] storage currentS = s.epochToScaleToSums[currentEpochCached][currentScaleCached];
        uint256 currentG = s.epochToScaleToG[currentEpochCached][currentScaleCached];

        // Record new snapshots of the latest running product P, sum S, and sum G, for the depositor
        s.depositSnapshots[_depositor].P = currentP;
        s.depositSnapshots[_depositor].G = currentG;
        s.depositSnapshots[_depositor].scale = currentScaleCached;
        s.depositSnapshots[_depositor].epoch = currentEpochCached;

        length = s.collateralTokens.length;
        for (uint256 i = 0; i < length; i++) {
            s.depositSums[_depositor][i] = currentS[i];
        }

        emit DepositSnapshotUpdated(_depositor, currentP, currentG);
    }

    // --- Reward ---
    function _accrueRewards(AppStorage.Layout storage s, address _depositor) internal {
        uint256 amount = _claimableReward(s, _depositor);
        s.storedPendingReward[_depositor] += amount;
    }

    function claimReward(address recipient) external returns (uint256 amount) {
        AppStorage.Layout storage s = AppStorage.layout();
        require(s._isClaimStart(), "StabilityPool: Claim not started");
        amount = _claimReward(s, msg.sender);

        if (amount > 0) {
            s.communityIssuance.transferAllocatedTokens(recipient, amount);
        }
        emit RewardClaimed(msg.sender, recipient, amount);
        return amount;
    }

    function _claimReward(AppStorage.Layout storage s, address account) internal returns (uint256 amount) {
        uint256 initialDeposit = s.accountDeposits[account].amount;

        if (initialDeposit > 0) {
            uint128 depositTimestamp = s.accountDeposits[account].timestamp;
            s._triggerOSHIIssuance();
            bool hasGains = _accrueDepositorCollateralGain(s, account);

            uint256 compoundedDebtDeposit = s._getCompoundedDebtDeposit(account);
            uint256 debtLoss = initialDeposit - compoundedDebtDeposit;

            amount = _claimableReward(s, account);
            // we update only if the snapshot has changed
            if (debtLoss > 0 || hasGains || amount > 0) {
                // Update deposit
                s.accountDeposits[account] =
                    AccountDeposit({amount: uint128(compoundedDebtDeposit), timestamp: depositTimestamp});
                _updateSnapshots(s, account, compoundedDebtDeposit);
            }
        }
        uint256 pending = s.storedPendingReward[account];
        if (pending > 0) {
            amount += pending;
            s.storedPendingReward[account] = 0;
        }
        return amount;
    }

    // set the time when the OSHI claim starts
    function setClaimStartTime(uint32 _claimStartTime) external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();
        s.claimStartTime = _claimStartTime;
        emit ClaimStartTimeSet(_claimStartTime);
    }

    // check the start time
    function isClaimStart() external view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s._isClaimStart();
    }

    function accountDeposits(address _depositor) external view returns (uint128 amount, uint128 timestamp) {
        AppStorage.Layout storage s = AppStorage.layout();
        amount = s.accountDeposits[_depositor].amount;
        timestamp = s.accountDeposits[_depositor].timestamp;
    }

    function collateralGainsByDepositor(address depositor, uint256 index) external view returns (uint80 gains) {
        AppStorage.Layout storage s = AppStorage.layout();
        gains = s.collateralGainsByDepositor[depositor][index];
    }

    function collateralTokens(uint256 index) external view returns (IERC20) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.collateralTokens[index];
    }

    function currentEpoch() external view returns (uint128) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.currentEpoch;
    }

    function currentScale() external view returns (uint128) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.currentScale;
    }

    function depositSnapshots(address depositor)
        external
        view
        returns (uint256 P, uint256 G, uint128 scale, uint128 epoch)
    {
        AppStorage.Layout storage s = AppStorage.layout();
        Snapshots memory snapshots = s.depositSnapshots[depositor];
        P = snapshots.P;
        G = snapshots.G;
        scale = snapshots.scale;
        epoch = snapshots.epoch;
    }

    function depositSums(address depositor, uint256 index) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.depositSums[depositor][index];
    }

    function epochToScaleToG(uint128 epoch, uint128 scale) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.epochToScaleToG[epoch][scale];
    }

    function epochToScaleToSums(uint128 epoch, uint128 scale, uint256 index) external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.epochToScaleToSums[epoch][scale][index];
    }

    function indexByCollateral(IERC20 collateral) external view returns (uint256 index) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.indexByCollateral[collateral];
    }

    function rewardRate() external view returns (uint128) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.spRewardRate;
    }

    function P() external view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.P;
    }

    function setRewardRate(uint128 _newRewardRate) external onlyRole(Config.OWNER_ROLE) {
        AppStorage.Layout storage s = AppStorage.layout();

        require(_newRewardRate <= Config.SP_MAX_REWARD_RATE, "StabilityPool: Reward rate too high");
        s._triggerOSHIIssuance();
        s.spRewardRate = _newRewardRate;
        emit RewardRateUpdated(_newRewardRate);
    }
}
