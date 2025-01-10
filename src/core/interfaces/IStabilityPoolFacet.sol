// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
// import {IDebtToken} from "./IDebtToken.sol";
// import {IFactory} from "./IFactory.sol";
// import {ILiquidationManager} from "./ILiquidationManager.sol";
// import {ICommunityIssuance} from "./ICommunityIssuance.sol";

struct AccountDeposit {
    uint128 amount;
    uint128 timestamp; // timestamp of the last deposit
}

struct Snapshots {
    uint256 P;
    uint256 G;
    uint128 scale;
    uint128 epoch;
}

struct SunsetIndex {
    uint128 idx;
    uint128 expiry;
}

struct Queue {
    uint16 firstSunsetIndexKey;
    uint16 nextSunsetIndexKey;
}

/// @title Stability Pool Facet Interface
/// @notice Interface for interacting with the Stability Pool Facet
interface IStabilityPoolFacet {
    /// @notice Emitted when collateral gains are withdrawn by a depositor
    /// @param _depositor The address of the depositor
    /// @param _collateralAmounts The amounts of collateral withdrawn
    event CollateralGainWithdrawn(address indexed _depositor, uint256[] _collateralAmounts);

    /// @notice Emitted when a depositor's snapshot is updated
    /// @param _depositor The address of the depositor
    /// @param _P The updated P value
    /// @param _G The updated G value
    event DepositSnapshotUpdated(address indexed _depositor, uint256 _P, uint256 _G);

    /// @notice Emitted when a reward is claimed
    /// @param account The address of the account claiming the reward
    /// @param recipient The address of the recipient of the reward
    /// @param claimed The amount of reward claimed
    event RewardClaimed(address indexed account, address indexed recipient, uint256 claimed);

    /// @notice Emitted when a user's deposit changes
    /// @param _depositor The address of the depositor
    /// @param _newDeposit The new deposit amount
    event UserDepositChanged(address indexed _depositor, uint256 _newDeposit);

    /// @notice Emitted when the claim start time is set
    /// @param _startTime The start time for claiming
    event ClaimStartTimeSet(uint256 _startTime);

    /// @notice Emitted when a collateral token is sunset
    /// @param _collateralToken The address of the collateral token
    event CollateralSunset(address indexed _collateralToken);

    /// @notice Emitted when the reward rate is updated
    /// @param _newRate The new reward rate
    event RewardRateUpdated(uint128 _newRate);

    /// @notice Claims collateral gains for a recipient
    /// @param recipient The address of the recipient
    /// @param collateralIndexes The indexes of the collateral to claim
    function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) external;

    /// @notice Provides a specified amount to the Stability Pool
    /// @param _amount The amount to provide
    function provideToSP(uint256 _amount) external;

    /// @notice Starts the sunset process for a collateral token
    /// @param collateralToken The collateral token to sunset
    function startCollateralSunset(IERC20 collateralToken) external;

    /// @notice Withdraws a specified amount from the Stability Pool
    /// @param _amount The amount to withdraw
    function withdrawFromSP(uint256 _amount) external;

    /// @notice Returns the deposit details of an account
    /// @param account The address of the account
    /// @return amount The deposit amount
    /// @return timestamp The timestamp of the last deposit
    function accountDeposits(address account) external view returns (uint128 amount, uint128 timestamp);

    /// @notice Returns the collateral gains by a depositor
    /// @param depositor The address of the depositor
    /// @param index The index of the collateral
    /// @return gains The collateral gains
    function collateralGainsByDepositor(address depositor, uint256 index) external view returns (uint80 gains);

    /// @notice Returns the collateral token at a specified index
    /// @param index The index of the collateral token
    /// @return The collateral token
    function collateralTokens(uint256 index) external view returns (IERC20);

    /// @notice Returns the current epoch
    /// @return The current epoch
    function currentEpoch() external view returns (uint128);

    /// @notice Returns the current scale
    /// @return The current scale
    function currentScale() external view returns (uint128);

    /// @notice Returns the deposit snapshots of an account
    /// @param account The address of the account
    /// @return P The P value
    /// @return G The G value
    /// @return scale The scale value
    /// @return epoch The epoch value
    function depositSnapshots(address account)
        external
        view
        returns (uint256 P, uint256 G, uint128 scale, uint128 epoch);

    /// @notice Returns the deposit sums for an account and index
    /// @param account The address of the account
    /// @param index The index
    /// @return The deposit sum
    function depositSums(address account, uint256 index) external view returns (uint256);

    /// @notice Returns the G value for a given epoch and scale
    /// @param epoch The epoch
    /// @param scale The scale
    /// @return The G value
    function epochToScaleToG(uint128 epoch, uint128 scale) external view returns (uint256);

    /// @notice Returns the sums for a given epoch, scale, and index
    /// @param epoch The epoch
    /// @param scale The scale
    /// @param index The index
    /// @return The sums
    function epochToScaleToSums(uint128 epoch, uint128 scale, uint256 index) external view returns (uint256);

    /// @notice Returns the compounded debt deposit for a depositor
    /// @param _depositor The address of the depositor
    /// @return The compounded debt deposit
    function getCompoundedDebtDeposit(address _depositor) external view returns (uint256);

    /// @notice Returns the collateral gains for a depositor
    /// @param _depositor The address of the depositor
    /// @return collateralGains The collateral gains
    function getDepositorCollateralGain(address _depositor) external view returns (uint256[] memory collateralGains);

    /// @notice Returns the total debt token deposits
    /// @return The total debt token deposits
    function getTotalDebtTokenDeposits() external view returns (uint256);

    /// @notice Returns the index of a collateral token
    /// @param collateral The collateral token
    /// @return index The index of the collateral token
    function indexByCollateral(IERC20 collateral) external view returns (uint256 index);

    /// @notice Returns the claimable reward for a depositor
    /// @param _depositor The address of the depositor
    /// @return The claimable reward
    function claimableReward(address _depositor) external view returns (uint256);

    /// @notice Claims the reward for a recipient
    /// @param recipient The address of the recipient
    /// @return amount The amount of reward claimed
    function claimReward(address recipient) external returns (uint256 amount);

    /// @notice Sets the claim start time
    /// @param _startTime The start time for claiming
    function setClaimStartTime(uint32 _startTime) external;

    /// @notice Checks if the claim start time has been reached
    /// @return True if the claim start time has been reached, false otherwise
    function isClaimStart() external view returns (bool);

    /// @notice Returns the current reward rate
    /// @return The current reward rate
    function rewardRate() external view returns (uint128);

    /// @notice Sets the Stability Pool reward rate
    /// @param _newRewardRate The new reward rate
    function setSPRewardRate(uint128 _newRewardRate) external;

    /// @notice Returns the P value
    /// @return The P value
    function P() external view returns (uint256);

    /// @notice Sets the reward rate
    /// @param _newRewardRate The new reward rate
    function setRewardRate(uint128 _newRewardRate) external;
}
