// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ICoreFacet } from "./ICoreFacet.sol";
import { ITroveManager } from "./ITroveManager.sol";

/// @notice Represents values related to a Trove Manager
struct TroveManagerValues {
    uint256 price;
    ///< The price of the collateral
    uint256 MCR;
    ///< Minimum Collateral Ratio
    bool sunsetting;
}
///< Indicates if the Trove Manager is being phased out

/// @notice Represents values involved in a liquidation process
struct LiquidationValues {
    uint256 entireTroveDebt;
    ///< Total debt of the trove
    uint256 entireTroveColl;
    ///< Total collateral of the trove
    uint256 collGasCompensation;
    ///< Collateral compensation for gas
    uint256 debtGasCompensation;
    ///< Debt compensation for gas
    uint256 debtToOffset;
    ///< Debt to be offset
    uint256 collToSendToSP;
    ///< Collateral to send to Stability Pool
    uint256 debtToRedistribute;
    ///< Debt to redistribute
    uint256 collToRedistribute;
    ///< Collateral to redistribute
    uint256 collSurplus;
}
///< Surplus collateral

/// @notice Represents total values involved in a sequence of liquidations
struct LiquidationTotals {
    uint256 totalCollInSequence;
    ///< Total collateral in the sequence
    uint256 totalDebtInSequence;
    ///< Total debt in the sequence
    uint256 totalCollGasCompensation;
    ///< Total collateral gas compensation
    uint256 totalDebtGasCompensation;
    ///< Total debt gas compensation
    uint256 totalDebtToOffset;
    ///< Total debt to offset
    uint256 totalCollToSendToSP;
    ///< Total collateral to send to Stability Pool
    uint256 totalDebtToRedistribute;
    ///< Total debt to redistribute
    uint256 totalCollToRedistribute;
    ///< Total collateral to redistribute
    uint256 totalCollSurplus;
}
///< Total collateral surplus

/// @title ILiquidationFacet
/// @notice Interface for liquidation-related functions and events
interface ILiquidationFacet {
    /// @notice Emitted when a liquidation occurs
    /// @param _liquidatedDebt The amount of debt liquidated
    /// @param _liquidatedColl The amount of collateral liquidated
    /// @param _collGasCompensation The collateral compensation for gas
    /// @param _debtGasCompensation The debt compensation for gas
    event Liquidation(
        uint256 _liquidatedDebt, uint256 _liquidatedColl, uint256 _collGasCompensation, uint256 _debtGasCompensation
    );

    /// @notice Emitted when troves are liquidated
    /// @param _troveManager The address of the Trove Manager
    /// @param _liquidatedDebt The amount of debt liquidated
    /// @param _liquidatedColl The amount of collateral liquidated
    /// @param _collGasCompensation The collateral compensation for gas
    /// @param _debtGasCompensation The debt compensation for gas
    event LiquidationTroves(
        address indexed _troveManager,
        uint256 _liquidatedDebt,
        uint256 _liquidatedColl,
        uint256 _collGasCompensation,
        uint256 _debtGasCompensation
    );

    /// @notice Emitted when a single trove is liquidated
    /// @param _borrower The address of the borrower
    /// @param _debt The amount of debt liquidated
    /// @param _coll The amount of collateral liquidated
    /// @param _operation The operation type
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);

    event GracePeriodDurationSet(uint128 _gracePeriod);

    error GracePeriodTooShort(uint128 gracePeriod);
    error NotInGracePeriod();
    error InGracePeriod();

    /// @notice Batch liquidates a list of troves
    /// @param troveManager The Trove Manager handling the liquidation
    /// @param _troveArray The array of trove addresses to be liquidated
    function batchLiquidateTroves(ITroveManager troveManager, address[] calldata _troveArray) external;

    /// @notice Liquidates a single trove
    /// @param troveManager The Trove Manager handling the liquidation
    /// @param borrower The address of the borrower whose trove is to be liquidated
    function liquidate(ITroveManager troveManager, address borrower) external;

    /// @notice Liquidates multiple troves up to a maximum number and collateral ratio
    /// @param troveManager The Trove Manager handling the liquidation
    /// @param maxTrovesToLiquidate The maximum number of troves to liquidate
    /// @param maxICR The maximum individual collateral ratio
    function liquidateTroves(ITroveManager troveManager, uint256 maxTrovesToLiquidate, uint256 maxICR) external;

    /// @notice Set the grace period for recovery mode
    /// @param _gracePeriod The new grace period
    function setGracePeriod(uint128 _gracePeriod) external;

    /// @notice Sync the grace period
    function syncGracePeriod() external;
}
