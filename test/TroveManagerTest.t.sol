// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CommunityIssuance } from "../src/OSHI/CommunityIssuance.sol";

import { OSHIToken } from "../src/OSHI/OSHIToken.sol";
import { RewardManager } from "../src/OSHI/RewardManager.sol";
import { ICommunityIssuance } from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import { IOSHIToken } from "../src/OSHI/interfaces/IOSHIToken.sol";
import { IRewardManager } from "../src/OSHI/interfaces/IRewardManager.sol";
import { DebtToken } from "../src/core/DebtToken.sol";
import { Initializer } from "../src/core/Initializer.sol";
import { SatoshiXApp } from "../src/core/SatoshiXApp.sol";

import { SortedTroves } from "../src/core/SortedTroves.sol";
import { TroveManager } from "../src/core/TroveManager.sol";
import { BorrowerOperationsFacet } from "../src/core/facets/BorrowerOperationsFacet.sol";
import { CoreFacet } from "../src/core/facets/CoreFacet.sol";
import { FactoryFacet } from "../src/core/facets/FactoryFacet.sol";
import { LiquidationFacet } from "../src/core/facets/LiquidationFacet.sol";
import { NexusYieldManagerFacet } from "../src/core/facets/NexusYieldManagerFacet.sol";
import { PriceFeedAggregatorFacet } from "../src/core/facets/PriceFeedAggregatorFacet.sol";
import { StabilityPoolFacet } from "../src/core/facets/StabilityPoolFacet.sol";

import { SatoshiPeriphery } from "../src/core/helpers/SatoshiPeriphery.sol";

import { IMultiCollateralHintHelpers } from "../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import { ISatoshiPeriphery } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { IWETH } from "../src/core/helpers/interfaces/IWETH.sol";
import { IBorrowerOperationsFacet } from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ICoreFacet } from "../src/core/interfaces/ICoreFacet.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { DeploymentParams, IFactoryFacet } from "../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../src/core/interfaces/ILiquidationFacet.sol";
import { INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { ISatoshiXApp } from "../src/core/interfaces/ISatoshiXApp.sol";

import { ISortedTroves } from "../src/core/interfaces/ISortedTroves.sol";
import { IStabilityPoolFacet } from "../src/core/interfaces/IStabilityPoolFacet.sol";
import { ITroveManager } from "../src/core/interfaces/ITroveManager.sol";

import { AggregatorV3Interface } from "../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";
import "./TestConfig.sol";

import { OracleMock, RoundData } from "./mocks/OracleMock.sol";
import { DeployBase } from "./utils/DeployBase.t.sol";
import { HintLib } from "./utils/HintLib.sol";
import { TroveBase } from "./utils/TroveBase.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

contract TroveManagerTest is DeployBase, TroveBase {
    uint256 maxFeePercentage = 0.05e18; // 5%
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;

    function setUp() public override {
        super.setUp();
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deployMockTroveManager(DEPLOYER);
    }

    function test_getTotalActiveCollateral() public {
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 0);
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 1e18);
    }

    function test_hasPendingRewards() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.hasPendingRewards(OWNER), false);
        assertEq(troveManagerBeaconProxy.hasPendingRewards(DEPLOYER), false);
    }

    function test_getRedemptionRate() public {
        assertEq(troveManagerBeaconProxy.getRedemptionRate(), 0.005e18);
    }

    function test_getRedemptionRateWithDecay() public {
        assertEq(troveManagerBeaconProxy.getRedemptionRateWithDecay(), 0.005e18);
    }

    function test_getBorrowingRate() public {
        assertEq(troveManagerBeaconProxy.getBorrowingRate(), 0.005e18);
    }

    function test_getBorrowingFee() public {
        assertEq(troveManagerBeaconProxy.getBorrowingFee(1000e18), 1000e18 / 200);
    }

    function test_setClaimStartTime() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.setClaimStartTime(100);
        assertEq(troveManagerBeaconProxy.claimStartTime(), 100);
    }

    function test_getTotalActiveDebt() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTotalActiveDebt(), 1000e18 + 1000e18 / 200 + DEBT_GAS_COMPENSATION);
    }

    function test_getRedemptionFeeWithDecay() public {
        assertEq(troveManagerBeaconProxy.getRedemptionFeeWithDecay(1000e18), 1000e18 / 200);
    }

    function test_getTroveStake() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTroveStake(OWNER), 1e18);
    }

    function test_getEntireSystemDebt() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getEntireSystemDebt(), 1000e18 + 1000e18 / 200 + DEBT_GAS_COMPENSATION);

        vm.warp(block.timestamp + 365 days);
        assertApproxEqAbs(
            troveManagerBeaconProxy.getEntireSystemDebt(),
            (1000e18 + 1000e18 / 200 + DEBT_GAS_COMPENSATION) * (10_000 + INTEREST_RATE_IN_BPS) / 10_000,
            10
        );
    }

    function test_setPause() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.setPaused(true);
        assertEq(troveManagerBeaconProxy.paused(), true);
    }

    function test_startSunset() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.startSunset();
        assertEq(troveManagerBeaconProxy.sunsetting(), true);
        assertEq(troveManagerBeaconProxy.lastActiveIndexUpdate(), block.timestamp);
        assertEq(troveManagerBeaconProxy.redemptionFeeFloor(), 0);
        assertEq(troveManagerBeaconProxy.maxSystemDebt(), 0);
    }

    function test_collectInterests() public {
        _openTrove(OWNER, 1e18, 1000e18);
        vm.expectRevert("Nothing to collect");
        troveManagerBeaconProxy.collectInterests();

        vm.warp(block.timestamp + 365 days);
        _updateRoundData(
            RoundData({
                answer: 4_000_000_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );
        _openTrove(USER_A, 1e18, 1000e18);
        vm.expectRevert("Nothing to collect");
        troveManagerBeaconProxy.collectInterests();
        assertGt(debtToken.balanceOf(address(rewardManager)), 0);
    }

    function test_removeTroveManager() public {
        vm.expectRevert("Trove Manager cannot be removed");
        borrowerOperationsProxy().removeTroveManager(troveManagerBeaconProxy);

        vm.prank(OWNER);
        troveManagerBeaconProxy.startSunset();

        borrowerOperationsProxy().removeTroveManager(troveManagerBeaconProxy);
    }

    /**
     * utils
     */
    function _updateRoundData(RoundData memory data) internal {
        updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _openTrove(address caller, uint256 collateralAmt, uint256 debtAmt) internal {
        openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            caller,
            caller,
            collateralMock,
            collateralAmt,
            debtAmt,
            maxFeePercentage
        );
    }
}
