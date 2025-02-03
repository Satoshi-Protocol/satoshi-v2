// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {ISortedTroves} from "./ISortedTroves.sol";
import {ICommunityIssuance} from "../../OSHI/interfaces/ICommunityIssuance.sol";

/// @title ITroveManager
/// @notice Interface for the Trove Manager contract
interface ITroveManager {
    /// @notice Emitted when the base rate is updated
    /// @param _baseRate The new base rate
    event BaseRateUpdated(uint256 _baseRate);

    /// @notice Emitted when collateral is sent
    /// @param _to The address to which the collateral is sent
    /// @param _amount The amount of collateral sent
    event CollateralSent(address _to, uint256 _amount);

    /// @notice Emitted when L terms are updated
    /// @param _L_collateral The updated L_collateral value
    /// @param _L_debt The updated L_debt value
    event LTermsUpdated(uint256 _L_collateral, uint256 _L_debt);

    /// @notice Emitted when the last fee operation time is updated
    /// @param _lastFeeOpTime The updated last fee operation time
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);

    /// @notice Emitted during a redemption operation
    /// @param _attemptedDebtAmount The attempted debt amount to redeem
    /// @param _actualDebtAmount The actual debt amount redeemed
    /// @param _collateralSent The amount of collateral sent
    /// @param _collateralFee The collateral fee
    event Redemption(
        uint256 _attemptedDebtAmount, uint256 _actualDebtAmount, uint256 _collateralSent, uint256 _collateralFee
    );

    /// @notice Emitted when system snapshots are updated
    /// @param _totalStakesSnapshot The total stakes snapshot
    /// @param _totalCollateralSnapshot The total collateral snapshot
    event SystemSnapshotsUpdated(uint256 _totalStakesSnapshot, uint256 _totalCollateralSnapshot);

    /// @notice Emitted when total stakes are updated
    /// @param _newTotalStakes The new total stakes
    event TotalStakesUpdated(uint256 _newTotalStakes);

    /// @notice Emitted when a trove index is updated
    /// @param _borrower The address of the borrower
    /// @param _newIndex The new index of the trove
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);

    /// @notice Emitted when trove snapshots are updated
    /// @param _L_collateral The updated L_collateral value
    /// @param _L_debt The updated L_debt value
    event TroveSnapshotsUpdated(uint256 _L_collateral, uint256 _L_debt);

    /// @notice Emitted when a trove is updated
    /// @param _borrower The address of the borrower
    /// @param _debt The updated debt value
    /// @param _coll The updated collateral value
    /// @param _stake The updated stake value
    /// @param _operation The operation performed on the trove
    event TroveUpdated(
        address indexed _borrower, uint256 _debt, uint256 _coll, uint256 _stake, TroveManagerOperation _operation
    );

    /// @notice Emitted when the configuration is set
    /// @param _sortedTroves The address of the sorted troves contract
    /// @param _collateralToken The address of the collateral token
    /// @param systemDeploymentTime The system deployment time
    /// @param sunsetting The sunsetting status
    /// @param activeInterestIndex The active interest index
    /// @param lastActiveIndexUpdate The last active index update time
    event SetConfig(
        address _sortedTroves,
        address _collateralToken,
        uint256 systemDeploymentTime,
        bool sunsetting,
        uint256 activeInterestIndex,
        uint256 lastActiveIndexUpdate
    );

    /// @notice Emitted when a reward is claimed
    /// @param account The address of the account claiming the reward
    /// @param recipient The address of the recipient receiving the reward
    /// @param claimed The amount of reward claimed
    event RewardClaimed(address indexed account, address indexed recipient, uint256 claimed);

    /// @notice Emitted when the claim start time is set
    /// @param _startTime The claim start time
    event ClaimStartTimeSet(uint32 _startTime);

    /// @notice Emitted when interest is collected
    /// @param _troveManager The address of the trove manager
    /// @param _amount The amount of interest collected
    event InterestCollected(address _troveManager, uint256 _amount);

    /// @notice Emitted when collateral is transferred
    /// @param _recipient The address of the recipient
    /// @param _amount The amount of collateral transferred
    event CollateralTransferred(address indexed _recipient, uint256 _amount);

    /// @notice Emitted when collateral is received
    /// @param _sender The address of the sender
    /// @param _amount The amount of collateral received
    event CollateralReceived(address indexed _sender, uint256 _amount);

    /// @notice Emitted when farming parameters are set
    /// @param _retainPercentage The retain percentage
    /// @param _refillPercentage The refill percentage
    event FarmingParamsSet(uint256 _retainPercentage, uint256 _refillPercentage);

    /// @notice Emitted when the vault manager is set
    /// @param _vaultManager The address of the vault manager
    event VaultManagerSet(address _vaultManager);

    /// @notice Error thrown when a non-privileged address attempts a privileged action
    /// @param sender The address of the sender
    error NotPrivileged(address sender);

    /// @notice Initializes the trove manager
    /// @param _owner The address of the owner
    /// @param _gasPool The address of the gas pool
    /// @param _debtToken The address of the debt token
    /// @param _communityIssuance The address of the community issuance contract
    /// @param _satoshiXApp The address of the SatoshiX app
    /// @param _debtGasCompensation The debt gas compensation
    function initialize(
        address _owner,
        address _gasPool,
        IDebtToken _debtToken,
        ICommunityIssuance _communityIssuance,
        address _satoshiXApp,
        uint256 _debtGasCompensation
    ) external;

    /// @notice Adds collateral surplus for a borrower
    /// @param borrower The address of the borrower
    /// @param collSurplus The amount of collateral surplus
    function addCollateralSurplus(address borrower, uint256 collSurplus) external;

    /// @notice Applies pending rewards for a borrower
    /// @param _borrower The address of the borrower
    /// @return coll The amount of collateral
    /// @return debt The amount of debt
    function applyPendingRewards(address _borrower) external returns (uint256 coll, uint256 debt);

    /// @notice Claims collateral for a receiver
    /// @param _receiver The address of the receiver
    function claimCollateral(address _receiver) external;

    /// @notice Closes a trove
    /// @param _borrower The address of the borrower
    /// @param _receiver The address of the receiver
    /// @param collAmount The amount of collateral
    /// @param debtAmount The amount of debt
    function closeTrove(address _borrower, address _receiver, uint256 collAmount, uint256 debtAmount) external;

    /// @notice Closes a trove by liquidation
    /// @param _borrower The address of the borrower
    function closeTroveByLiquidation(address _borrower) external;

    /// @notice Collects interests
    function collectInterests() external;

    /// @notice Decays the base rate and gets the borrowing fee
    /// @param _debt The amount of debt
    /// @return The borrowing fee
    function decayBaseRateAndGetBorrowingFee(uint256 _debt) external returns (uint256);

    /// @notice Decreases debt and sends collateral
    /// @param account The address of the account
    /// @param debt The amount of debt
    /// @param coll The amount of collateral
    function decreaseDebtAndSendCollateral(address account, uint256 debt, uint256 coll) external;

    /// @notice Fetches the price
    /// @return The price
    function fetchPrice() external returns (uint256);

    /// @notice Finalizes a liquidation
    /// @param _liquidator The address of the liquidator
    /// @param _debt The amount of debt
    /// @param _coll The amount of collateral
    /// @param _collSurplus The amount of collateral surplus
    /// @param _debtGasComp The debt gas compensation
    /// @param _collGasComp The collateral gas compensation
    function finalizeLiquidation(
        address _liquidator,
        uint256 _debt,
        uint256 _coll,
        uint256 _collSurplus,
        uint256 _debtGasComp,
        uint256 _collGasComp
    ) external;

    /// @notice Gets the entire system balances
    /// @return The total debt, total collateral, and total stakes
    function getEntireSystemBalances() external returns (uint256, uint256, uint256);

    /// @notice Moves pending trove rewards to active balances
    /// @param _debt The amount of debt
    /// @param _collateral The amount of collateral
    function movePendingTroveRewardsToActiveBalances(uint256 _debt, uint256 _collateral) external;

    /// @notice Opens a trove
    /// @param _borrower The address of the borrower
    /// @param _collateralAmount The amount of collateral
    /// @param _compositeDebt The composite debt
    /// @param NICR The nominal individual collateral ratio
    /// @param _upperHint The upper hint address
    /// @param _lowerHint The lower hint address
    /// @return stake The stake
    /// @return arrayIndex The array index
    function openTrove(
        address _borrower,
        uint256 _collateralAmount,
        uint256 _compositeDebt,
        uint256 NICR,
        address _upperHint,
        address _lowerHint
    ) external returns (uint256 stake, uint256 arrayIndex);

    /// @notice Redeems collateral
    /// @param _debtAmount The amount of debt
    /// @param _firstRedemptionHint The first redemption hint address
    /// @param _upperPartialRedemptionHint The upper partial redemption hint address
    /// @param _lowerPartialRedemptionHint The lower partial redemption hint address
    /// @param _partialRedemptionHintNICR The partial redemption hint NICR
    /// @param _maxIterations The maximum number of iterations
    /// @param _maxFeePercentage The maximum fee percentage
    function redeemCollateral(
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external;

    /// @notice Sets the configuration
    /// @param _sortedTroves The address of the sorted troves contract
    /// @param _collateralToken The address of the collateral token
    function setConfig(ISortedTroves _sortedTroves, IERC20 _collateralToken) external;

    /// @notice Sets the parameters
    /// @param _minuteDecayFactor The minute decay factor
    /// @param _redemptionFeeFloor The redemption fee floor
    /// @param _maxRedemptionFee The maximum redemption fee
    /// @param _borrowingFeeFloor The borrowing fee floor
    /// @param _maxBorrowingFee The maximum borrowing fee
    /// @param _interestRateInBPS The interest rate in basis points
    /// @param _maxSystemDebt The maximum system debt
    /// @param _MCR The minimum collateral ratio
    /// @param _rewardRate The reward rate
    /// @param _claimStartTime The claim start time
    function setParameters(
        uint256 _minuteDecayFactor,
        uint256 _redemptionFeeFloor,
        uint256 _maxRedemptionFee,
        uint256 _borrowingFeeFloor,
        uint256 _maxBorrowingFee,
        uint256 _interestRateInBPS,
        uint256 _maxSystemDebt,
        uint256 _MCR,
        uint128 _rewardRate,
        uint32 _claimStartTime
    ) external;

    /// @notice Sets the trove manager reward rate
    /// @param _newRewardRate The new reward rate
    function setTMRewardRate(uint128 _newRewardRate) external;

    /// @notice Sets the paused status
    /// @param _paused The paused status
    function setPaused(bool _paused) external;

    /// @notice Starts the sunset process
    function startSunset() external;

    /// @notice Updates balances
    function updateBalances() external;

    /// @notice Updates a trove from adjustment
    /// @param _isDebtIncrease Whether the debt is increased
    /// @param _debtChange The change in debt
    /// @param _netDebtChange The net change in debt
    /// @param _isCollIncrease Whether the collateral is increased
    /// @param _collChange The change in collateral
    /// @param _upperHint The upper hint address
    /// @param _lowerHint The lower hint address
    /// @param _borrower The address of the borrower
    /// @param _receiver The address of the receiver
    /// @return The updated debt, collateral, and stake
    function updateTroveFromAdjustment(
        bool _isDebtIncrease,
        uint256 _debtChange,
        uint256 _netDebtChange,
        bool _isCollIncrease,
        uint256 _collChange,
        address _upperHint,
        address _lowerHint,
        address _borrower,
        address _receiver
    ) external returns (uint256, uint256, uint256);

    /// @notice Gets the bootstrap period
    /// @return The bootstrap period
    function BOOTSTRAP_PERIOD() external view returns (uint256);

    /// @notice Gets the L_collateral value
    /// @return The L_collateral value
    function L_collateral() external view returns (uint256);

    /// @notice Gets the L_debt value
    /// @return The L_debt value
    function L_debt() external view returns (uint256);

    /// @notice Gets the maximum interest rate in basis points
    /// @return The maximum interest rate in basis points
    function MAX_INTEREST_RATE_IN_BPS() external view returns (uint256);

    /// @notice Gets the minimum collateral ratio
    /// @return The minimum collateral ratio
    function MCR() external view returns (uint256);

    /// @notice Gets the sunsetting interest rate
    /// @return The sunsetting interest rate
    function SUNSETTING_INTEREST_RATE() external view returns (uint256);

    /// @notice Gets the trove details for a given address
    /// @param _borrower The address of the borrower
    /// @return debt The debt value
    /// @return coll The collateral value
    /// @return stake The stake value
    /// @return status The status of the trove
    /// @return arrayIndex The array index
    /// @return activeInterestIndex The active interest index
    function troves(address _borrower)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 stake,
            Status status,
            uint128 arrayIndex,
            uint256 activeInterestIndex
        );

    /// @notice Gets the active interest index
    /// @return The active interest index
    function activeInterestIndex() external view returns (uint256);

    /// @notice Gets the base rate
    /// @return The base rate
    function baseRate() external view returns (uint256);

    /// @notice Gets the SatoshiX app address
    /// @return The SatoshiX app address
    function satoshiXApp() external view returns (address);

    /// @notice Gets the borrowing fee floor
    /// @return The borrowing fee floor
    function borrowingFeeFloor() external view returns (uint256);

    /// @notice Gets the collateral token
    /// @return The collateral token
    function collateralToken() external view returns (IERC20);

    /// @notice Gets the debt token
    /// @return The debt token
    function debtToken() external view returns (IDebtToken);

    /// @notice Gets the defaulted collateral
    /// @return The defaulted collateral
    function defaultedCollateral() external view returns (uint256);

    /// @notice Gets the defaulted debt
    /// @return The defaulted debt
    function defaultedDebt() external view returns (uint256);

    /// @notice Gets the borrowing fee for a given debt amount
    /// @param _debt The debt amount
    /// @return The borrowing fee
    function getBorrowingFee(uint256 _debt) external view returns (uint256);

    /// @notice Gets the borrowing fee with decay for a given debt amount
    /// @param _debt The debt amount
    /// @return The borrowing fee with decay
    function getBorrowingFeeWithDecay(uint256 _debt) external view returns (uint256);

    /// @notice Gets the borrowing rate
    /// @return The borrowing rate
    function getBorrowingRate() external view returns (uint256);

    /// @notice Gets the borrowing rate with decay
    /// @return The borrowing rate with decay
    function getBorrowingRateWithDecay() external view returns (uint256);

    /// @notice Gets the current individual collateral ratio for a borrower
    /// @param _borrower The address of the borrower
    /// @param _price The price
    /// @return The current individual collateral ratio
    function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);

    /// @notice Gets the entire debt and collateral for a borrower
    /// @param _borrower The address of the borrower
    /// @return debt The debt value
    /// @return coll The collateral value
    /// @return pendingDebtReward The pending debt reward
    /// @return pendingCollateralReward The pending collateral reward
    function getEntireDebtAndColl(address _borrower)
        external
        view
        returns (uint256 debt, uint256 coll, uint256 pendingDebtReward, uint256 pendingCollateralReward);

    /// @notice Gets the entire system collateral
    /// @return The entire system collateral
    function getEntireSystemColl() external view returns (uint256);

    /// @notice Gets the entire system debt
    /// @return The entire system debt
    function getEntireSystemDebt() external view returns (uint256);

    /// @notice Gets the nominal individual collateral ratio for a borrower
    /// @param _borrower The address of the borrower
    /// @return The nominal individual collateral ratio
    function getNominalICR(address _borrower) external view returns (uint256);

    /// @notice Gets the pending collateral and debt rewards for a borrower
    /// @param _borrower The address of the borrower
    /// @return The pending collateral reward
    /// @return The pending debt reward
    function getPendingCollAndDebtRewards(address _borrower) external view returns (uint256, uint256);

    /// @notice Gets the redemption fee with decay for a given collateral amount
    /// @param _collateralDrawn The collateral amount
    /// @return The redemption fee with decay
    function getRedemptionFeeWithDecay(uint256 _collateralDrawn) external view returns (uint256);

    /// @notice Gets the redemption rate
    /// @return The redemption rate
    function getRedemptionRate() external view returns (uint256);

    /// @notice Gets the redemption rate with decay
    /// @return The redemption rate with decay
    function getRedemptionRateWithDecay() external view returns (uint256);

    /// @notice Gets the total active collateral
    /// @return The total active collateral
    function getTotalActiveCollateral() external view returns (uint256);

    /// @notice Gets the total active debt
    /// @return The total active debt
    function getTotalActiveDebt() external view returns (uint256);

    /// @notice Gets the collateral and debt for a borrower's trove
    /// @param _borrower The address of the borrower
    /// @return coll The collateral value
    /// @return debt The debt value
    function getTroveCollAndDebt(address _borrower) external view returns (uint256 coll, uint256 debt);

    /// @notice Gets the trove from the trove owners array
    /// @param _index The index
    /// @return The address of the trove owner
    function getTroveFromTroveOwnersArray(uint256 _index) external view returns (address);

    /// @notice Gets the count of trove owners
    /// @return The count of trove owners
    function getTroveOwnersCount() external view returns (uint256);

    /// @notice Gets the stake for a borrower's trove
    /// @param _borrower The address of the borrower
    /// @return The stake value
    function getTroveStake(address _borrower) external view returns (uint256);

    /// @notice Gets the status of a borrower's trove
    /// @param _borrower The address of the borrower
    /// @return The status value
    function getTroveStatus(address _borrower) external view returns (uint256);

    /// @notice Checks if a borrower has pending rewards
    /// @param _borrower The address of the borrower
    /// @return True if the borrower has pending rewards, false otherwise
    function hasPendingRewards(address _borrower) external view returns (bool);

    /// @notice Gets the interest payable
    /// @return The interest payable
    function interestPayable() external view returns (uint256);

    /// @notice Gets the interest rate
    /// @return The interest rate
    function interestRate() external view returns (uint256);

    /// @notice Gets the last active index update time
    /// @return The last active index update time
    function lastActiveIndexUpdate() external view returns (uint256);

    /// @notice Gets the last collateral error for redistribution
    /// @return The last collateral error for redistribution
    function lastCollateralError_Redistribution() external view returns (uint256);

    /// @notice Gets the last debt error for redistribution
    /// @return The last debt error for redistribution
    function lastDebtError_Redistribution() external view returns (uint256);

    /// @notice Gets the last fee operation time
    /// @return The last fee operation time
    function lastFeeOperationTime() external view returns (uint256);

    /// @notice Gets the maximum borrowing fee
    /// @return The maximum borrowing fee
    function maxBorrowingFee() external view returns (uint256);

    /// @notice Gets the maximum redemption fee
    /// @return The maximum redemption fee
    function maxRedemptionFee() external view returns (uint256);

    /// @notice Gets the maximum system debt
    /// @return The maximum system debt
    function maxSystemDebt() external view returns (uint256);

    /// @notice Gets the minute decay factor
    /// @return The minute decay factor
    function minuteDecayFactor() external view returns (uint256);

    /// @notice Checks if the system is paused
    /// @return True if the system is paused, false otherwise
    function paused() external view returns (bool);

    /// @notice Gets the redemption fee floor
    /// @return The redemption fee floor
    function redemptionFeeFloor() external view returns (uint256);

    /// @notice Gets the reward snapshots for a given address
    /// @param _borrower The address of the borrower
    /// @return collateral The collateral value
    /// @return debt The debt value
    function rewardSnapshots(address _borrower) external view returns (uint256 collateral, uint256 debt);

    /// @notice Gets the sorted troves contract
    /// @return The sorted troves contract
    function sortedTroves() external view returns (ISortedTroves);

    /// @notice Checks if the system is sunsetting
    /// @return True if the system is sunsetting, false otherwise
    function sunsetting() external view returns (bool);

    /// @notice Gets the surplus balances for a given address
    /// @param _borrower The address of the borrower
    /// @return The surplus balance
    function surplusBalances(address _borrower) external view returns (uint256);

    /// @notice Gets the system deployment time
    /// @return The system deployment time
    function systemDeploymentTime() external view returns (uint256);

    /// @notice Gets the total collateral snapshot
    /// @return The total collateral snapshot
    function totalCollateralSnapshot() external view returns (uint256);

    /// @notice Gets the total stakes
    /// @return The total stakes
    function totalStakes() external view returns (uint256);

    /// @notice Gets the total stakes snapshot
    /// @return The total stakes snapshot
    function totalStakesSnapshot() external view returns (uint256);

    /// @notice Claims a reward for a recipient
    /// @param _recipient The address of the recipient
    /// @return The amount of reward claimed
    function claimReward(address _recipient) external returns (uint256);

    /// @notice Sets the claim start time
    /// @param _claimStartTime The claim start time
    function setClaimStartTime(uint32 _claimStartTime) external;

    /// @notice Gets the claimable reward for a given address
    /// @param _borrower The address of the borrower
    /// @return The claimable reward
    function claimableReward(address _borrower) external view returns (uint256);

    /// @notice Checks if the claim start time has been reached
    /// @return True if the claim start time has been reached, false otherwise
    function isClaimStart() external view returns (bool);

    /// @notice Gets the reward rate
    /// @return The reward rate
    function rewardRate() external view returns (uint128);

    /// @notice Gets the last update time
    /// @return The last update time
    function lastUpdate() external view returns (uint256);

    /// @notice Gets the claim start time
    /// @return The claim start time
    function claimStartTime() external view returns (uint32);

    /// @notice Transfers collateral to a privileged vault
    /// @param amount The amount of collateral
    function transferCollToPrivilegedVault(uint256 amount) external;

    /// @notice Receives collateral from a privileged vault
    /// @param amount The amount of collateral
    function receiveCollFromPrivilegedVault(uint256 amount) external;

    /// @notice Sets the farming parameters
    /// @param retainPercentage The retain percentage
    /// @param refillPercentage The refill percentage
    function setFarmingParams(uint256 retainPercentage, uint256 refillPercentage) external;

    /// @notice Sets the vault manager
    /// @param vaultManager_ The address of the vault manager
    function setVaultManager(address vaultManager_) external;

    /// @notice Gets the retain percentage
    /// @return The retain percentage
    function retainPercentage() external view returns (uint256);

    /// @notice Gets the refill percentage
    /// @return The refill percentage
    function refillPercentage() external view returns (uint256);

    /// @notice Gets the farming precision
    /// @return The farming precision
    function FARMING_PRECISION() external view returns (uint256);
}

/// @notice Enum representing the status of a trove
enum Status {
    nonExistent,
    active,
    closedByOwner,
    closedByLiquidation,
    closedByRedemption
}

/// @notice Enum representing the operations that can be performed on a trove
enum TroveManagerOperation {
    open,
    close,
    adjust,
    liquidate,
    redeemCollateral
}

/// @notice Struct representing the necessary data for a trove
struct Trove {
    uint256 debt;
    uint256 coll;
    uint256 stake;
    Status status;
    uint128 arrayIndex;
    uint256 activeInterestIndex;
}

/// @notice Struct representing volume data
struct VolumeData {
    uint32 amount;
    uint32 week;
    uint32 day;
}

/// @notice Struct representing redemption totals
struct RedemptionTotals {
    uint256 remainingDebt;
    uint256 totalDebtToRedeem;
    uint256 totalCollateralDrawn;
    uint256 collateralFee;
    uint256 collateralToSendToRedeemer;
    uint256 decayedBaseRate;
    uint256 price;
    uint256 totalDebtSupplyAtStart;
}

/// @notice Struct representing single redemption values
struct SingleRedemptionValues {
    uint256 debtLot;
    uint256 collateralLot;
    bool cancelledPartial;
}

/// @notice Struct representing the collateral and debt snapshots for a given active trove
struct RewardSnapshot {
    uint256 collateral;
    uint256 debt;
}

/// @notice Struct representing farming parameters
struct FarmingParams {
    uint256 retainPercentage;
    uint256 refillPercentage;
}
