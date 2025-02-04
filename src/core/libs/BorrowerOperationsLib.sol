// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SatoshiMath } from "../../library/SatoshiMath.sol";
import { AppStorage } from "../AppStorage.sol";

import { Config } from "../Config.sol";
import { TroveManagerData } from "../interfaces/IBorrowerOperationsFacet.sol";
import { Balances } from "../interfaces/IBorrowerOperationsFacet.sol";
import { ITroveManager } from "../interfaces/ITroveManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library BorrowerOperationsLib {
    /**
     * @notice Get total collateral and debt balances for all active collaterals, as well as
     *             the current collateral prices
     *     @dev Not a view because fetching from the oracle is state changing.
     *          Can still be accessed as a view from within the UX.
     */
    function _fetchBalances(AppStorage.Layout storage s) internal returns (Balances memory balances) {
        uint256 loopEnd = s.troveManagers.length;
        balances = Balances({
            collaterals: new uint256[](loopEnd),
            debts: new uint256[](loopEnd),
            prices: new uint256[](loopEnd),
            decimals: new uint8[](loopEnd)
        });
        for (uint256 i; i < loopEnd;) {
            ITroveManager troveManager = s.troveManagers[i];
            (uint256 collateral, uint256 debt, uint256 price) = troveManager.getEntireSystemBalances();
            balances.collaterals[i] = collateral;
            balances.debts[i] = debt;
            balances.prices[i] = price;
            balances.decimals[i] = IERC20Metadata(address(troveManager.collateralToken())).decimals();
            unchecked {
                ++i;
            }
        }
    }

    function _getGlobalSystemBalances(AppStorage.Layout storage s)
        internal
        returns (uint256 totalPricedCollateral, uint256 totalDebt)
    {
        Balances memory balances = _fetchBalances(s);
        (, totalPricedCollateral, totalDebt) = _getTCRData(balances);
    }

    function _getCollateralAndTCRData(
        AppStorage.Layout storage s,
        ITroveManager troveManager
    )
        internal
        returns (
            IERC20 collateralToken,
            uint256 price,
            uint256 totalPricedCollateral,
            uint256 totalDebt,
            bool isRecoveryMode
        )
    {
        TroveManagerData storage t = s.troveManagersData[troveManager];
        uint256 index;
        (collateralToken, index) = (t.collateralToken, t.index);

        require(address(collateralToken) != address(0), "Collateral not enabled");

        uint256 amount;
        Balances memory balances = _fetchBalances(s);
        (amount, totalPricedCollateral, totalDebt) = BorrowerOperationsLib._getTCRData(balances);
        isRecoveryMode = _checkRecoveryMode(amount);

        return (collateralToken, balances.prices[index], totalPricedCollateral, totalDebt, isRecoveryMode);
    }

    function _isCallerOrDelegated(AppStorage.Layout storage s, address _account) internal view returns (bool) {
        return msg.sender == _account || s.isApprovedDelegate[_account][msg.sender];
    }

    function _getCollChange(
        uint256 _collReceived,
        uint256 _requestedCollWithdrawal
    )
        internal
        pure
        returns (uint256 collChange, bool isCollIncrease)
    {
        if (_collReceived != 0) {
            collChange = _collReceived;
            isCollIncrease = true;
        } else {
            collChange = _requestedCollWithdrawal;
        }
    }

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewICRFromTroveChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price,
        uint8 decimals
    )
        internal
        pure
        returns (uint256)
    {
        (uint256 newColl, uint256 newDebt) =
            _getNewTroveAmounts(_coll, _debt, _collChange, _isCollIncrease, _debtChange, _isDebtIncrease);

        uint256 scaledCollAmount = SatoshiMath._getScaledCollateralAmount(newColl, decimals);
        uint256 newICR = SatoshiMath._computeCR(scaledCollAmount, newDebt, _price);
        return newICR;
    }

    function _getNewTroveAmounts(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    )
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 newColl = _coll;
        uint256 newDebt = _debt;

        newColl = _isCollIncrease ? _coll + _collChange : _coll - _collChange;
        newDebt = _isDebtIncrease ? _debt + _debtChange : _debt - _debtChange;

        return (newColl, newDebt);
    }

    function _getNewTCRFromTroveChange(
        uint256 totalColl,
        uint256 totalDebt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint8 decimals
    )
        internal
        pure
        returns (uint256)
    {
        totalDebt = _isDebtIncrease ? totalDebt + _debtChange : totalDebt - _debtChange;
        totalColl = _isCollIncrease ? totalColl + _collChange : totalColl - _collChange;

        uint256 scaledCollAmount = SatoshiMath._getScaledCollateralAmount(totalColl, decimals);
        uint256 newTCR = SatoshiMath._computeCR(scaledCollAmount, totalDebt);
        return newTCR;
    }

    function _getTCRData(Balances memory balances)
        internal
        pure
        returns (uint256 amount, uint256 totalPricedCollateral, uint256 totalDebt)
    {
        uint256 loopEnd = balances.collaterals.length;
        for (uint256 i; i < loopEnd;) {
            totalPricedCollateral += (
                SatoshiMath._getScaledCollateralAmount(balances.collaterals[i], balances.decimals[i])
                    * balances.prices[i]
            );
            totalDebt += balances.debts[i];
            unchecked {
                ++i;
            }
        }
        amount = SatoshiMath._computeCR(totalPricedCollateral, totalDebt);

        return (amount, totalPricedCollateral, totalDebt);
    }

    function _checkRecoveryMode(uint256 TCR) internal pure returns (bool) {
        return TCR < Config.CCR;
    }

    function _requireICRisAboveMCR(uint256 _newICR, uint256 MCR) internal pure {
        require(_newICR >= MCR, "BorrowerOps: An operation that would result in ICR < MCR is not permitted");
    }

    function _requireICRisAboveCCR(uint256 _newICR) internal pure {
        require(_newICR >= Config.CCR, "BorrowerOps: Operation must leave trove with ICR >= CCR");
    }

    function _requireNewICRisAboveOldICR(uint256 _newICR, uint256 _oldICR) internal pure {
        require(_newICR >= _oldICR, "BorrowerOps: Cannot decrease your Trove's ICR in Recovery Mode");
    }

    function _requireNewTCRisAboveCCR(uint256 _newTCR) internal pure {
        require(_newTCR >= Config.CCR, "BorrowerOps: An operation that would result in TCR < CCR is not permitted");
    }

    function _requireAtLeastMinNetDebt(AppStorage.Layout storage s, uint256 _netDebt) internal view {
        require(_netDebt >= s.minNetDebt, "BorrowerOps: Trove's net debt must be greater than minimum");
    }

    function _requireValidMaxFeePercentage(uint256 _maxFeePercentage) internal pure {
        require(
            _maxFeePercentage <= SatoshiMath.DECIMAL_PRECISION, "Max fee percentage must less than or equal to 100%"
        );
    }
}
