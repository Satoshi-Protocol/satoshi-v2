// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {
    IStabilityPoolFacet, AccountDeposit, Snapshots, SunsetIndex, Queue
} from "../interfaces/IStabilityPoolFacet.sol";
import {Config} from "../Config.sol";
import {AppStorage} from "../storages/AppStorage.sol";
import {StabilityPoolLib} from "../libs/StabilityPoolLib.sol";

contract StabilityPool is IStabilityPoolFacet, SatoshiOwnable {
    using SafeERC20 for IERC20;
    using StabilityPoolLib for AppStorage.Layout;

    mapping(address => AccountDeposit) public accountDeposits; // depositor address -> initial deposit
    mapping(address => Snapshots) public depositSnapshots; // depositor address -> snapshots struct

    // index values are mapped against the values within `collateralTokens`
    mapping(address => uint256[256]) public depositSums; // depositor address -> sums

    // depositor => gains
    mapping(address => uint80[256]) public collateralGainsByDepositor;

    mapping(address => uint256) private storedPendingReward;

    /*
     * Similarly, the sum 'G' is used to calculate OSHI gains. During it's lifetime, each deposit d_t earns a OSHI gain of
     *  ( d_t * [G - G_t] )/P_t, where G_t is the depositor's snapshot of G taken at time t when the deposit was made.
     *
     *  OSHI reward events occur are triggered by depositor operations (new deposit, topup, withdrawal), and liquidations.
     *  In each case, the OSHI reward is issued (i.e. G is updated), before other state changes are made.
     */
    mapping(uint128 => mapping(uint128 => uint256)) public epochToScaleToG;

    // constructor() {
    //     _disableInitializers();
    // }

    // /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // // solhint-disable-next-line no-empty-blocks
    // function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
    //     // No additional authorization logic is needed for this contract
    // }

    // function initialize(
    //     ISatoshiCore _satoshiCore,
    //     IDebtToken _debtToken,
    //     IFactory _factory,
    //     ILiquidationManager _liquidationManager,
    //     ICommunityIssuance _communityIssuance
    // ) external initializer {
    //     __UUPSUpgradeable_init_unchained();
    //     __SatoshiOwnable_init(_satoshiCore);
    //     debtToken = _debtToken;
    //     factory = _factory;
    //     liquidationManager = _liquidationManager;
    //     P = DECIMAL_PRECISION;
    //     communityIssuance = _communityIssuance;
    //     lastUpdate = uint32(block.timestamp);
    // }

    // function enableCollateral(IERC20 _collateral) external {
    //     require(msg.sender == address(factory), "Not factory");
    //     uint256 length = collateralTokens.length;
    //     bool collateralEnabled;
    //     for (uint256 i = 0; i < length; i++) {
    //         if (collateralTokens[i] == _collateral) {
    //             collateralEnabled = true;
    //             break;
    //         }
    //     }
    //     if (!collateralEnabled) {
    //         Queue memory queueCached = queue;
    //         if (queueCached.nextSunsetIndexKey > queueCached.firstSunsetIndexKey) {
    //             SunsetIndex memory sIdx = _sunsetIndexes[queueCached.firstSunsetIndexKey];
    //             if (sIdx.expiry < block.timestamp) {
    //                 delete _sunsetIndexes[queue.firstSunsetIndexKey++];
    //                 _overwriteCollateral(_collateral, sIdx.idx);
    //                 return;
    //             }
    //         }
    //         collateralTokens.push(_collateral);
    //         indexByCollateral[_collateral] = collateralTokens.length;
    //     } else {
    //         // revert if the factory is trying to deploy a new TM with a sunset collateral
    //         require(indexByCollateral[_collateral] > 0, "Collateral is sunsetting");
    //     }
    // }

    function setSPRewardRate(uint128 _newRewardRate) external onlyOwner {
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
    function startCollateralSunset(IERC20 collateral) external onlyOwner {
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
        require(!s.paused(), "Deposits are paused");
        require(_amount > 0, "StabilityPool: Amount must be non-zero");

        s._triggerOSHIIssuance();

        _accrueDepositorCollateralGain(s, msg.sender);

        uint256 compoundedDebtDeposit = getCompoundedDebtDeposit(msg.sender);

        _accrueRewards(msg.sender);

        s.debtToken.sendToSP(msg.sender, _amount);
        uint256 newTotalDebtTokenDeposits = s.totalDebtTokenDeposits + _amount;
        s.totalDebtTokenDeposits = newTotalDebtTokenDeposits;
        emit StabilityPoolLib.StabilityPoolDebtBalanceUpdated(newTotalDebtTokenDeposits);

        uint256 newDeposit = compoundedDebtDeposit + _amount;
        accountDeposits[msg.sender] = AccountDeposit({amount: uint128(newDeposit), timestamp: uint128(block.timestamp)});

        _updateSnapshots(msg.sender, newDeposit);
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
        uint256 initialDeposit = accountDeposits[msg.sender].amount;
        uint128 depositTimestamp = accountDeposits[msg.sender].timestamp;
        require(initialDeposit > 0, "StabilityPool: User must have a non-zero deposit");
        require(depositTimestamp < block.timestamp, "!Deposit and withdraw same block");

        AppStorage.Layout storage s = AppStorage.layout();
        s._triggerOSHIIssuance();

        _accrueDepositorCollateralGain(s, msg.sender);

        uint256 compoundedDebtDeposit = getCompoundedDebtDeposit(msg.sender);
        uint256 debtToWithdraw = SatoshiMath._min(_amount, compoundedDebtDeposit);

        _accrueRewards(msg.sender);

        if (debtToWithdraw > 0) {
            s.debtToken.returnFromPool(address(this), msg.sender, debtToWithdraw);
            s._decreaseDebt(debtToWithdraw);
        }

        // Update deposit
        uint256 newDeposit = compoundedDebtDeposit - debtToWithdraw;
        accountDeposits[msg.sender] = AccountDeposit({amount: uint128(newDeposit), timestamp: depositTimestamp});

        _updateSnapshots(msg.sender, newDeposit);
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
        uint80[256] storage depositorGains = collateralGainsByDepositor[_depositor];
        for (uint256 i = 0; i < collateralGains.length; i++) {
            collateralGains[i] = depositorGains[i];
        }

        uint256 P_Snapshot = depositSnapshots[_depositor].P;
        if (P_Snapshot == 0) return collateralGains;
        uint256 initialDeposit = accountDeposits[_depositor].amount;
        uint128 epochSnapshot = depositSnapshots[_depositor].epoch;
        uint128 scaleSnapshot = depositSnapshots[_depositor].scale;
        uint256[256] storage sums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot];
        uint256[256] storage nextSums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
        uint256[256] storage depSums = depositSums[_depositor];

        for (uint256 i = 0; i < collateralGains.length; i++) {
            if (sums[i] == 0) continue; // Collateral was overwritten or not gains
            uint256 firstPortion = sums[i] - depSums[i];
            uint256 secondPortion = nextSums[i] / Config.SCALE_FACTOR;
            uint8 _decimals = IERC20Metadata(address(s.collateralTokens[i])).decimals();
            collateralGains[i] += initialDeposit
                * SatoshiMath._getOriginalCollateralAmount(firstPortion + secondPortion, _decimals) / P_Snapshot
                / Config.DECIMAL_PRECISION;
        }
        return collateralGains;
    }

    function _accrueDepositorCollateralGain(AppStorage.Layout storage s, address _depositor)
        private
        returns (bool hasGains)
    {
        uint80[256] storage depositorGains = collateralGainsByDepositor[_depositor];
        uint256 collaterals = s.collateralTokens.length;
        uint256 initialDeposit = accountDeposits[_depositor].amount;
        hasGains = false;
        if (initialDeposit == 0) {
            return hasGains;
        }

        uint128 epochSnapshot = depositSnapshots[_depositor].epoch;
        uint128 scaleSnapshot = depositSnapshots[_depositor].scale;
        uint256 P_Snapshot = depositSnapshots[_depositor].P;

        uint256[256] storage sums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot];
        uint256[256] storage nextSums = s.epochToScaleToSums[epochSnapshot][scaleSnapshot + 1];
        uint256[256] storage depSums = depositSums[_depositor];

        for (uint256 i = 0; i < collaterals; i++) {
            if (sums[i] == 0) continue; // Collateral was overwritten or not gains
            hasGains = true;
            uint256 firstPortion = sums[i] - depSums[i];
            uint256 secondPortion = nextSums[i] / Config.SCALE_FACTOR;
            uint8 _decimals = IERC20Metadata(address(s.collateralTokens[i])).decimals();
            depositorGains[i] += uint80(
                (
                    initialDeposit * SatoshiMath._getOriginalCollateralAmount(firstPortion + secondPortion, _decimals)
                        / P_Snapshot / Config.DECIMAL_PRECISION
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
        uint256 initialDeposit = accountDeposits[_depositor].amount;

        if (totalDebt == 0 || initialDeposit == 0) {
            return storedPendingReward[_depositor] + _claimableReward(_depositor);
        }

        Snapshots memory snapshots = depositSnapshots[_depositor];
        uint128 epochSnapshot = snapshots.epoch;
        uint128 scaleSnapshot = snapshots.scale;
        uint256 oshiNumerator = (s._OSHIIssuance() * Config.DECIMAL_PRECISION) + s.lastOSHIError;
        uint256 oshiPerUnitStaked = oshiNumerator / totalDebt;
        uint256 marginalOSHIGain = (epochSnapshot == s.currentEpoch) ? oshiPerUnitStaked * s.P : 0;
        uint256 firstPortion;
        uint256 secondPortion;

        if (scaleSnapshot == s.currentScale) {
            firstPortion = epochToScaleToG[epochSnapshot][scaleSnapshot] - snapshots.G + marginalOSHIGain;
            secondPortion = epochToScaleToG[epochSnapshot][scaleSnapshot + 1] / Config.SCALE_FACTOR;
        } else {
            firstPortion = epochToScaleToG[epochSnapshot][scaleSnapshot] - snapshots.G;
            secondPortion = (epochToScaleToG[epochSnapshot][scaleSnapshot + 1] + marginalOSHIGain) / Config.SCALE_FACTOR;
        }

        return storedPendingReward[_depositor]
            + (initialDeposit * (firstPortion + secondPortion)) / snapshots.P / Config.DECIMAL_PRECISION;
    }

    function _claimableReward(address _depositor) private view returns (uint256) {
        uint256 initialDeposit = accountDeposits[_depositor].amount;
        if (initialDeposit == 0) {
            return 0;
        }

        Snapshots memory snapshots = depositSnapshots[_depositor];

        return _getOSHIGainFromSnapshots(initialDeposit, snapshots);
    }

    function _getOSHIGainFromSnapshots(uint256 initialStake, Snapshots memory snapshots)
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

        uint256 firstPortion = epochToScaleToG[epochSnapshot][scaleSnapshot] - G_Snapshot;
        uint256 secondPortion = epochToScaleToG[epochSnapshot][scaleSnapshot + 1] / Config.SCALE_FACTOR;

        uint256 OSHIGain = (initialStake * (firstPortion + secondPortion)) / P_Snapshot / Config.DECIMAL_PRECISION;

        return OSHIGain;
    }

    // --- Compounded deposit ---

    /*
     * Return the user's compounded deposit. Given by the formula:  d = d0 * P/P(0)
     * where P(0) is the depositor's snapshot of the product P, taken when they last updated their deposit.
     */
    function getCompoundedDebtDeposit(address _depositor) public view returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        uint256 initialDeposit = accountDeposits[_depositor].amount;
        if (initialDeposit == 0) {
            return 0;
        }

        Snapshots memory snapshots = depositSnapshots[_depositor];

        uint256 compoundedDeposit = _getCompoundedStakeFromSnapshots(s, initialDeposit, snapshots);
        return compoundedDeposit;
    }

    // Internal function, used to calculcate compounded deposits and compounded front end stakes.
    function _getCompoundedStakeFromSnapshots(
        AppStorage.Layout storage s,
        uint256 initialStake,
        Snapshots memory snapshots
    ) internal view returns (uint256) {
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

    // --- Sender functions for Debt deposit, collateral gains and Satoshi gains ---
    function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) public virtual {
        uint256 compoundedDebtDeposit = getCompoundedDebtDeposit(msg.sender);
        uint128 depositTimestamp = accountDeposits[msg.sender].timestamp;
        _accrueDepositorCollateralGain(msg.sender);

        AppStorage.Layout storage s = AppStorage.layout();
        uint256 loopEnd = collateralIndexes.length;
        uint256[] memory collateralGains = new uint256[](s.collateralTokens.length);

        uint80[256] storage depositorGains = collateralGainsByDepositor[msg.sender];
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
        accountDeposits[msg.sender] =
            AccountDeposit({amount: uint128(compoundedDebtDeposit), timestamp: depositTimestamp});
        _updateSnapshots(s, msg.sender, compoundedDebtDeposit);
        emit CollateralGainWithdrawn(msg.sender, collateralGains);
    }

    // --- Stability Pool Deposit Functionality ---

    function _updateSnapshots(AppStorage.Layout storage s, address _depositor, uint256 _newValue) internal {
        uint256 length;
        if (_newValue == 0) {
            delete depositSnapshots[_depositor];

            length = s.collateralTokens.length;
            for (uint256 i = 0; i < length; i++) {
                depositSums[_depositor][i] = 0;
            }
            emit DepositSnapshotUpdated(_depositor, 0, 0);
            return;
        }
        uint128 currentScaleCached = s.currentScale;
        uint128 currentEpochCached = s.currentEpoch;
        uint256 currentP = s.P;

        // Get S and G for the current epoch and current scale
        uint256[256] storage currentS = s.epochToScaleToSums[currentEpochCached][currentScaleCached];
        uint256 currentG = epochToScaleToG[currentEpochCached][currentScaleCached];

        // Record new snapshots of the latest running product P, sum S, and sum G, for the depositor
        depositSnapshots[_depositor].P = currentP;
        depositSnapshots[_depositor].G = currentG;
        depositSnapshots[_depositor].scale = currentScaleCached;
        depositSnapshots[_depositor].epoch = currentEpochCached;

        length = s.collateralTokens.length;
        for (uint256 i = 0; i < length; i++) {
            depositSums[_depositor][i] = currentS[i];
        }

        emit DepositSnapshotUpdated(_depositor, currentP, currentG);
    }

    // --- Reward ---
    function _accrueRewards(address _depositor) internal {
        uint256 amount = _claimableReward(_depositor);
        storedPendingReward[_depositor] = storedPendingReward[_depositor] + amount;
    }

    function claimReward(address recipient) external returns (uint256 amount) {
        AppStorage.Layout storage s = AppStorage.layout();
        require(isClaimStart(), "StabilityPool: Claim not started");
        amount = _claimReward(msg.sender);

        if (amount > 0) {
            s.communityIssuance.transferAllocatedTokens(recipient, amount);
        }
        emit RewardClaimed(msg.sender, recipient, amount);
        return amount;
    }

    function _claimReward(AppStorage.Layout storage s, address account) internal returns (uint256 amount) {
        uint256 initialDeposit = accountDeposits[account].amount;

        if (initialDeposit > 0) {
            uint128 depositTimestamp = accountDeposits[account].timestamp;
            s._triggerOSHIIssuance();
            bool hasGains = _accrueDepositorCollateralGain(account);

            uint256 compoundedDebtDeposit = getCompoundedDebtDeposit(account);
            uint256 debtLoss = initialDeposit - compoundedDebtDeposit;

            amount = _claimableReward(account);
            // we update only if the snapshot has changed
            if (debtLoss > 0 || hasGains || amount > 0) {
                // Update deposit
                accountDeposits[account] =
                    AccountDeposit({amount: uint128(compoundedDebtDeposit), timestamp: depositTimestamp});
                _updateSnapshots(account, compoundedDebtDeposit);
            }
        }
        uint256 pending = storedPendingReward[account];
        if (pending > 0) {
            amount += pending;
            storedPendingReward[account] = 0;
        }
        return amount;
    }

    // set the time when the OSHI claim starts
    function setClaimStartTime(uint32 _claimStartTime) external onlyOwner {
        AppStorage.Layout storage s = AppStorage.layout();
        s.claimStartTime = _claimStartTime;
        emit ClaimStartTimeSet(_claimStartTime);
    }

    // check the start time
    function isClaimStart() public view returns (bool) {
        AppStorage.Layout storage s = AppStorage.layout();
        return s.claimStartTime <= uint32(block.timestamp);
    }
}
