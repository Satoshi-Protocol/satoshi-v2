// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AppStorage} from "../storages/AppStorage.sol";
import {Balances} from "../interfaces/IBorrowerOperationsFacet.sol";
import {SatoshiMath} from "../../library/SatoshiMath.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {Config} from "../Config.sol";

library BorrowerOperationsLib {
    function _checkRecoveryMode(uint256 TCR) internal pure returns (bool) {
        return TCR < Config.CCR;
    }

    function _getGlobalSystemBalances(AppStorage.Layout storage s)
        internal
        returns (uint256 totalPricedCollateral, uint256 totalDebt)
    {
        Balances memory balances = _fetchBalances(s);
        (, totalPricedCollateral, totalDebt) = _getTCRData(balances);
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
}
