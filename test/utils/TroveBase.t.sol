// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IMultiCollateralHintHelpers } from "../../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import { IBorrowerOperationsFacet } from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ISortedTroves } from "../../src/core/interfaces/ISortedTroves.sol";
import { IStabilityPoolFacet } from "../../src/core/interfaces/IStabilityPoolFacet.sol";
import { ITroveManager } from "../../src/core/interfaces/ITroveManager.sol";
import { OracleMock, RoundData } from "../mocks/OracleMock.sol";
import { HintLib } from "./HintLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console } from "forge-std/Test.sol";

interface IOracleMock {
    function updateRoundData(RoundData memory roundData) external;
}

abstract contract TroveBase is Test {
    /// @notice Internal function to open trove for the unit test that need to have an existing trove
    function openTrove(
        IBorrowerOperationsFacet borrowerOperationsProxy,
        ISortedTroves sortedTrovesBeaconProxy,
        ITroveManager troveManagerBeaconProxy,
        IMultiCollateralHintHelpers hintHelpers,
        uint256 gasCompensation,
        address caller,
        address account,
        IERC20 collateral,
        uint256 collateralAmt,
        uint256 debtAmt,
        uint256 maxFeePercentage
    )
        internal
    {
        vm.startPrank(caller);

        deal(address(collateral), caller, collateralAmt);
        collateral.approve(address(borrowerOperationsProxy), collateralAmt);

        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, collateralAmt, debtAmt, gasCompensation
        );
        // open trove tx execution
        borrowerOperationsProxy.openTrove(
            troveManagerBeaconProxy, account, maxFeePercentage, collateralAmt, debtAmt, upperHint, lowerHint
        );

        vm.stopPrank();
    }

    function closeTrove(
        IBorrowerOperationsFacet borrowerOperationsProxy,
        ITroveManager troveManagerBeaconProxy,
        address caller
    )
        internal
    {
        vm.startPrank(caller);
        borrowerOperationsProxy.closeTrove(troveManagerBeaconProxy, caller);
        vm.stopPrank();
    }

    function provideToSP(IStabilityPoolFacet stabilityPoolProxy, address caller, uint256 amount) internal {
        vm.startPrank(caller);
        stabilityPoolProxy.provideToSP(amount);
        vm.stopPrank();
    }

    function withdrawFromSP(IStabilityPoolFacet stabilityPoolProxy, address caller, uint256 amount) internal {
        vm.startPrank(caller);
        stabilityPoolProxy.withdrawFromSP(amount);
        vm.stopPrank();
    }

    function updateRoundData(address oracleMock, address caller, RoundData memory roundData) internal {
        vm.startPrank(caller);
        IOracleMock(oracleMock).updateRoundData(roundData);
        vm.stopPrank();
    }
}
