// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IMultiCollateralHintHelpers } from "../../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import { ISortedTroves } from "../../src/core/interfaces/ISortedTroves.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { SatoshiMath } from "../../src/library/SatoshiMath.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library HintLib {
    using Math for uint256;

    uint256 internal constant TRIAL_NUMBER = 15;
    uint256 internal constant RANDOM_SEED = 42;

    function getHint(
        IMultiCollateralHintHelpers hintHelpers,
        ISortedTroves sortedTrovesBeaconProxy,
        ITroveManager troveManagerBeaconProxy,
        uint256 collateralAmt,
        uint256 netDebtAmt,
        uint256 gasCompensation
    )
        internal
        view
        returns (address, address)
    {
        uint256 borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(netDebtAmt);
        uint256 totalDebt = netDebtAmt + borrowingFee + gasCompensation;
        uint256 NICR = collateralAmt.mulDiv(SatoshiMath.NICR_PRECISION, totalDebt);
        uint256 numTroves = sortedTrovesBeaconProxy.getSize();
        uint256 numTrials = numTroves * TRIAL_NUMBER;
        (address approxHint,,) = hintHelpers.getApproxHint(troveManagerBeaconProxy, NICR, numTrials, RANDOM_SEED);
        (address upperHint, address lowerHint) =
            sortedTrovesBeaconProxy.findInsertPosition(NICR, approxHint, approxHint);

        return (upperHint, lowerHint);
    }
}
