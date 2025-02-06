// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPriceFeed } from "../../priceFeed/interfaces/IPriceFeed.sol";

import { IDebtToken } from "../interfaces/IDebtToken.sol";
import { ISortedTroves } from "../interfaces/ISortedTroves.sol";
import { ITroveManager } from "../interfaces/ITroveManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Parameters for deploying a new instance
struct DeploymentParams {
    uint256 minuteDecayFactor; // 999037758833783500  (half life of 12 hours)
    uint256 redemptionFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxRedemptionFee; // 1e18  (100%)
    uint256 borrowingFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxBorrowingFee; // 1e18 / 100 * 5  (5%)
    uint256 interestRateInBps; // 450 (4.5%)
    uint256 maxDebt; // 1e18 * 1000000000 (1 billion)
    uint256 MCR; // 11 * 1e17  (110%)
    uint128 rewardRate; // 57077625570776256 (9000000e18 / (5 * 31536000))
    uint256 OSHIAllocation; // 20 * _1_MILLION
    uint32 claimStartTime; // 1713542400  (2024-04-20 0:0:0)
}

interface IFactoryFacet {
    /// @notice Emitted when a new deployment is created
    /// @param collateral The collateral token used
    /// @param priceFeed The price feed used
    /// @param troveManager The trove manager instance
    /// @param sortedTroves The sorted troves instance
    event NewDeployment(
        IERC20 indexed collateral, IPriceFeed priceFeed, ITroveManager troveManager, ISortedTroves sortedTroves
    );

    /// @notice Emitted when collateral is configured
    /// @param troveManager The trove manager instance
    /// @param collateralToken The collateral token configured
    event CollateralConfigured(ITroveManager troveManager, IERC20 indexed collateralToken);

    /// @notice Emitted when collateral is overwritten
    /// @param oldCollateralToken The old collateral token
    /// @param newCollateralToken The new collateral token
    event CollateralOverwritten(IERC20 oldCollateralToken, IERC20 newCollateralToken);

    /// @notice Deploys a new instance with the given parameters
    /// @param collateralToken The collateral token to use
    /// @param priceFeed The price feed to use
    /// @param params The deployment parameters
    /// @return The trove manager and sorted troves instances
    function deployNewInstance(
        IERC20 collateralToken,
        IPriceFeed priceFeed,
        DeploymentParams memory params
    )
        external
        returns (ITroveManager, ISortedTroves);

    /// @notice Returns the count of trove managers
    /// @return The number of trove managers
    function troveManagerCount() external view returns (uint256);

    /// @notice Returns the trove manager at a specific index
    /// @param index The index of the trove manager
    /// @return The trove manager instance
    function troveManagers(uint256 index) external view returns (ITroveManager);

    /// @notice Sets the reward rate for trove managers
    /// @param _numerator The numerators for the reward rate
    /// @param _denominator The denominator for the reward rate
    function setTMRewardRate(uint128[] calldata _numerator, uint128 _denominator) external;

    /// @notice Returns the maximum reward rate for trove managers
    /// @return The maximum reward rate
    function maxTMRewardRate() external view returns (uint128);
}
