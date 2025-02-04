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
import { ISatoshiPeriphery, LzSendParam } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
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
import { ITroveManager, TroveManagerOperation } from "../src/core/interfaces/ITroveManager.sol";
import { SatoshiMath } from "../src/library/SatoshiMath.sol";

import { AggregatorV3Interface } from "../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";
import "./TestConfig.sol";

import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { OracleMock, RoundData } from "./mocks/OracleMock.sol";
import { DeployBase, LocalVars } from "./utils/DeployBase.t.sol";
import { HintLib } from "./utils/HintLib.sol";
import { TroveBase } from "./utils/TroveBase.t.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

contract SatoshiPeripheryTest is DeployBase, TroveBase {
    using Math for uint256;

    uint256 maxFeePercentage = 0.05e18; // 5%
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    address user;
    address user1;
    address user2;
    address user3;
    address user4;
    ERC20Mock collateral;

    struct LiquidationVars {
        uint256 entireTroveDebt;
        uint256 entireTroveColl;
        uint256 collGasCompensation;
        uint256 debtGasCompensation;
        uint256 debtToOffset;
        uint256 collToSendToSP;
        uint256 debtToRedistribute;
        uint256 collToRedistribute;
        uint256 collSurplus;
        // user state
        uint256[5] userCollBefore;
        uint256[5] userCollAfter;
        uint256[5] userDebtBefore;
        uint256[5] userDebtAfter;
    }

    function setUp() public override {
        super.setUp();
        // testing user
        user = vm.addr(5);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deployMockTroveManager(DEPLOYER);
        collateral = ERC20Mock(address(collateralMock));

        // user set delegate approval for satoshiPeriphery
        vm.startPrank(user);
        borrowerOperationsProxy().setDelegateApproval(address(satoshiPeriphery), true);
        vm.stopPrank();
    }

    function testOpenTroveByRouter() public {
        LocalVars memory vars;
        // open trove params
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD

        vm.startPrank(user);
        collateral.mint(user, vars.collAmt);

        // state before
        vars.rewardManagerDebtAmtBefore = debtToken.balanceOf(address(rewardManager));
        vars.gasPoolDebtAmtBefore = debtToken.balanceOf(address(gasPool));
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.stake = vars.collAmt;
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.collAmt,
            vars.debtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        collateral.approve(address(satoshiPeriphery), vars.collAmt);
        satoshiPeriphery.openTrove(
            troveManagerBeaconProxy,
            maxFeePercentage,
            vars.collAmt,
            vars.debtAmt,
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.rewardManagerDebtAmtAfter = debtToken.balanceOf(address(rewardManager));
        vars.gasPoolDebtAmtAfter = debtToken.balanceOf(address(gasPool));
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.rewardManagerDebtAmtAfter, vars.rewardManagerDebtAmtBefore + vars.borrowingFee);
        assertEq(vars.gasPoolDebtAmtAfter, vars.gasPoolDebtAmtBefore + DEBT_GAS_COMPENSATION);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.debtAmt);
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.collAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.collAmt);

        vm.stopPrank();
    }

    function testAddCollByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;

        vm.startPrank(user);
        collateral.mint(user, vars.addCollAmt);
        collateral.approve(address(borrowerOperationsProxy()), vars.addCollAmt);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vars.stake = vars.totalCollAmt;

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.debtAmt,
            DEBT_GAS_COMPENSATION
        );
        // tx execution
        collateral.approve(address(satoshiPeriphery), vars.addCollAmt);
        satoshiPeriphery.addColl(troveManagerBeaconProxy, vars.addCollAmt, vars.upperHint, vars.lowerHint);

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);

        vm.stopPrank();
    }

    function testWithdrawCollByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;

        vm.startPrank(user);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vars.stake = vars.totalCollAmt;
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.debtAmt,
            DEBT_GAS_COMPENSATION
        );
        // tx execution
        satoshiPeriphery.withdrawColl(troveManagerBeaconProxy, vars.withdrawCollAmt, vars.upperHint, vars.lowerHint);

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        // assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);

        vm.stopPrank();
    }

    function testWithdrawDebtByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawDebtAmt = 10_000e18;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);

        // state before
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vars.stake = vars.collAmt;

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.collAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );
        // tx execution
        satoshiPeriphery.withdrawDebt(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            vars.withdrawDebtAmt,
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function _openTrove(address caller, uint256 collateralAmt, uint256 debtAmt) internal {
        TroveBase.openTrove(
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
            0.05e18
        );
    }

    function testRepayDebtByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.repayDebtAmt = 5000e18;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        debtToken.approve(address(satoshiPeriphery), vars.repayDebtAmt);

        // state before
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vars.stake = vars.collAmt;
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.collAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        satoshiPeriphery.repayDebt(troveManagerBeaconProxy, vars.repayDebtAmt, vars.upperHint, vars.lowerHint);

        // state after
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_AddCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        collateral.mint(user, vars.addCollAmt);
        debtToken.approve(address(satoshiPeriphery), vars.repayDebtAmt);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vars.stake = vars.totalCollAmt;
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        collateral.approve(address(satoshiPeriphery), vars.addCollAmt);
        satoshiPeriphery.adjustTrove(
            troveManagerBeaconProxy,
            0, /* vars.maxFeePercentage */
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_AddCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.withdrawDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);
        collateral.mint(user, vars.addCollAmt);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vars.stake = vars.totalCollAmt;
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        collateral.approve(address(satoshiPeriphery), vars.addCollAmt);
        satoshiPeriphery.adjustTrove(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_WithdrawCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        debtToken.approve(address(satoshiPeriphery), vars.repayDebtAmt);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        satoshiPeriphery.adjustTrove(
            troveManagerBeaconProxy,
            0, /* vars.maxFeePercentage */
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_WithdrawCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.withdrawDebtAmt = 2000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);

        // state before
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy().getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        // check TroveUpdated event
        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            DEBT_GAS_COMPENSATION
        );

        // tx execution
        satoshiPeriphery.adjustTrove(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            LzSendParam(0, "", MessagingFee(0, 0))
        );

        // state after
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testCloseTroveByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10_000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user,
            user,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vm.startPrank(user);
        //  mock user debt token balance
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.repayDebtAmt = vars.debtAmt + vars.borrowingFee;
        deal(address(debtToken), user, vars.repayDebtAmt);
        debtToken.approve(address(satoshiPeriphery), vars.repayDebtAmt);

        // state before
        vars.debtTokenTotalSupplyBefore = debtToken.totalSupply();
        vars.userBalanceBefore = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        // tx execution
        satoshiPeriphery.closeTrove(troveManagerBeaconProxy);

        // state after
        vars.userDebtAmtAfter = debtToken.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtToken.totalSupply();
        vars.userBalanceAfter = collateral.balanceOf(user);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userDebtAmtAfter, 0);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt - DEBT_GAS_COMPENSATION
        );
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.collAmt);
        // assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.collAmt);

        vm.stopPrank();
    }

    function testLiquidateByRouter() public {
        LiquidationVars memory vars;
        LocalVars memory lvars;
        lvars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        lvars.debtAmt = 10_000e18; // 10000 USD
        lvars.maxFeePercentage = 0.05e18; // 5%

        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user2,
            user2,
            collateral,
            lvars.collAmt,
            lvars.debtAmt,
            lvars.maxFeePercentage
        );

        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user3,
            user3,
            collateral,
            lvars.collAmt,
            lvars.debtAmt,
            lvars.maxFeePercentage
        );

        TroveBase.openTrove(
            borrowerOperationsProxy(),
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            DEBT_GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            lvars.collAmt,
            lvars.debtAmt,
            lvars.maxFeePercentage
        );

        // reducing TCR below 150%, and all Troves below 100% ICR
        _updateRoundData(
            RoundData({
                answer: 1_000_000_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );

        (uint256 coll1, uint256 debt1) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 coll2Before, uint256 debt2Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (uint256 coll3Before, uint256 debt3Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        vars.collToRedistribute = (coll1 - coll1 / LIQUIDATION_FEE);
        vars.debtToRedistribute = debt1;
        vars.collGasCompensation = coll1 / LIQUIDATION_FEE;
        vars.debtGasCompensation = DEBT_GAS_COMPENSATION;

        vm.prank(user4);
        satoshiPeriphery.liquidateTroves(troveManagerBeaconProxy, 1, 110e18, LzSendParam(0, "", MessagingFee(0, 0)));

        (uint256 coll2, uint256 debt2) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (uint256 coll3, uint256 debt3) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);

        assertEq(coll2, coll2Before + vars.collToRedistribute / 2);
        assertEq(debt2, debt2Before + vars.debtToRedistribute / 2);
        assertEq(coll3, coll3Before + vars.collToRedistribute / 2);
        assertEq(debt3, debt3Before + vars.debtToRedistribute / 2);

        // // check user4 gets the reward for liquidation
        assertEq(collateral.balanceOf(user4), vars.collGasCompensation / 2);
        assertEq(collateral.balanceOf(user4), vars.collGasCompensation / 2);
        assertEq(debtToken.balanceOf(user4), vars.debtGasCompensation);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }
}
