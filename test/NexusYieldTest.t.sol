// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestConfig.sol";
import {Config} from "../src/core/Config.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {SatoshiMath} from "../src/library/SatoshiMath.sol";
import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {ISatoshiXApp} from "../src/core/interfaces/ISatoshiXApp.sol";
import {BorrowerOperationsFacet} from "../src/core/facets/BorrowerOperationsFacet.sol";
import {IBorrowerOperationsFacet} from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import {CoreFacet} from "../src/core/facets/CoreFacet.sol";
import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {ITroveManager, TroveManagerOperation} from "../src/core/interfaces/ITroveManager.sol";
import {FactoryFacet} from "../src/core/facets/FactoryFacet.sol";
import {IFactoryFacet, DeploymentParams} from "../src/core/interfaces/IFactoryFacet.sol";
import {LiquidationFacet} from "../src/core/facets/LiquidationFacet.sol";
import {ILiquidationFacet} from "../src/core/interfaces/ILiquidationFacet.sol";
import {PriceFeedAggregatorFacet} from "../src/core/facets/PriceFeedAggregatorFacet.sol";
import {IPriceFeedAggregatorFacet} from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import {StabilityPoolFacet} from "../src/core/facets/StabilityPoolFacet.sol";
import {IStabilityPoolFacet} from "../src/core/interfaces/IStabilityPoolFacet.sol";
import {INexusYieldManagerFacet, AssetConfig} from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import {NexusYieldManagerFacet} from "../src/core/facets/NexusYieldManagerFacet.sol";
import {Initializer} from "../src/core/Initializer.sol";
import {IRewardManager, LockDuration} from "../src/OSHI/interfaces/IRewardManager.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {ICommunityIssuance} from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import {CommunityIssuance} from "../src/OSHI/CommunityIssuance.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {ISortedTroves} from "../src/core/interfaces/ISortedTroves.sol";
import {IPriceFeed} from "../src/priceFeed/IPriceFeed.sol";
import {AggregatorV3Interface} from "../src/priceFeed/AggregatorV3Interface.sol";
import {IOSHIToken} from "../src/OSHI/interfaces/IOSHIToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {ISatoshiPeriphery, LzSendParam} from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/core/helpers/SatoshiPeriphery.sol";
import {IMultiCollateralHintHelpers} from "../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {RoundData, OracleMock} from "./mocks/OracleMock.sol";
import {HintLib} from "./utils/HintLib.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract mock6 is ERC20Mock {
    constructor() ERC20Mock("MOCK", "MOCK") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract mock27 is ERC20Mock {
    constructor() ERC20Mock("MOCK", "MOCK") {}

    function decimals() public pure override returns (uint8) {
        return 27;
    }
}

contract NexusYieldTest is DeployBase, TroveBase {
    using Math for uint256;

    uint256 maxFeePercentage = 0.05e18; // 5%
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user;
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;
    ERC20Mock collateral;
    INexusYieldManagerFacet nexusYieldProxy;

    struct RewardManagerVars {
        uint256[5] SATGain;
        // user state
        uint256[5] userCollBefore;
        uint256[5] userCollAfter;
        uint256[5] userDebtBefore;
        uint256[5] userDebtAfter;
        uint256[5] userMintingFee;
        uint256 ClaimableOSHIinSP;
        uint256[5] claimableTroveReward;
    }

    function setUp() public override {
        super.setUp();
        // testing user
        user = vm.addr(5);
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        user5 = vm.addr(6);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deployMockTroveManager(DEPLOYER);
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
        collateral = ERC20Mock(address(collateralMock));
        nexusYieldProxy = getNexusYieldProxy();

        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateral),
            AssetConfig(
                priceFeedAggregatorProxy(),
                10,
                10,
                10000e18,
                1000e18,
                0,
                false,
                3 days,
                1.1e18,
                0.9e18,
                uint256(collateral.decimals())
            )
        );
        debtTokenProxy().rely(address(nexusYieldProxy));
        rewardManagerProxy().setWhitelistCaller(address(nexusYieldProxy), true);
        vm.stopPrank();
    }

    function test_swapInAndOut_noFee() public {
        // assume collateral is the stable coin
        deal(address(collateralMock), user1, 100e18);

        vm.startPrank(OWNER);
        nexusYieldProxy.setPrivileged(user1, true);

        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1e18);
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 1e18);

        // check the debtTokenMinted
        assertEq(nexusYieldProxy.debtTokenMinted(address(collateralMock)), 1e18);

        // check user1 sat balance
        assertEq(debtTokenProxy().balanceOf(user1), 1e18);

        // swap out
        nexusYieldProxy.swapOutPrivileged(address(collateralMock), user1, 1e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);

        vm.stopPrank();
    }

    function test_pause() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isNymPaused());
        // pause again
        vm.expectRevert(INexusYieldManagerFacet.AlreadyPaused.selector);
        nexusYieldProxy.pause();
        vm.stopPrank();
    }

    function test_resume() public {
        vm.startPrank(OWNER);
        // not pause should revert
        vm.expectRevert(INexusYieldManagerFacet.NotPaused.selector);
        nexusYieldProxy.resume();
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isNymPaused());
        nexusYieldProxy.resume();
        assertFalse(nexusYieldProxy.isNymPaused());
        vm.stopPrank();
    }

    function test_transferTokenToPrivilegedVault() public {
        vm.startPrank(OWNER);
        deal(address(collateralMock), address(nexusYieldProxy), 100e18);
        // transfer to non-privileged address should revert
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.NotPrivileged.selector, user1));
        nexusYieldProxy.transferTokenToPrivilegedVault(address(collateralMock), user1, 100e18);
        nexusYieldProxy.setPrivileged(user1, true);
        nexusYieldProxy.transferTokenToPrivilegedVault(address(collateralMock), user1, 100e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);
        vm.stopPrank();
    }

    function test_swapIn() public {
        deal(address(collateralMock), user1, 10001e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1001e18);
        uint256 dailyMintCount = nexusYieldProxy.dailyMintCount(address(collateralMock));
        uint256 amounToMint = 1001e18;
        uint256 dailyDebtTokenMintCap = nexusYieldProxy.dailyDebtTokenMintCap(address(collateralMock));
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManagerFacet.DebtTokenDailyMintCapReached.selector,
                dailyMintCount,
                amounToMint,
                dailyDebtTokenMintCap
            )
        );
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1001e18);

        nexusYieldProxy.swapIn(address(collateralMock), user1, 1e18);

        // the next day
        vm.warp(block.timestamp + 1 days);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 2e18);
        assertEq(nexusYieldProxy.dailyMintCount(address(collateralMock)), 2e18);

        // swapIn 0
        vm.expectRevert(INexusYieldManagerFacet.ZeroAmount.selector);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 0);

        vm.stopPrank();
    }

    function test_swapInZeroFee() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateral),
            AssetConfig(
                priceFeedAggregatorProxy(),
                0,
                0,
                10000e18,
                1000e18,
                0,
                false,
                3 days,
                1.1e18,
                0.9e18,
                uint256(collateral.decimals())
            )
        );

        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1e18);
        assertEq(debtTokenProxy().balanceOf(user1), 1e18);
        vm.stopPrank();
    }

    function test_previewSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
        // check daily mint cap remain
        assertEq(nexusYieldProxy.debtTokenDailyMintCapRemain(address(collateralMock)), 900e18);
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        (uint256 assetOut, uint256 feeOut) = nexusYieldProxy.previewSwapOut(address(collateralMock), amount);
        assertEq(fee, feeOut);
        assertEq(assetOut + feeOut, amount);
        vm.stopPrank();
    }

    function test_previewSwapStableForSAT() public {
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeIn(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        (uint256 previewAmount,) = nexusYieldProxy.previewSwapIn(address(collateralMock), amount);
        assertEq(previewAmount, amount - fee);
    }

    function test_scheduleSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        debtTokenProxy().approve(address(nexusYieldProxy), amount);
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);

        (uint256 previewAmount, uint256 previewFee) = nexusYieldProxy.previewSwapOut(address(collateralMock), amount);
        (uint256 pendingAmount, uint32 withdrawalTime) =
            nexusYieldProxy.pendingWithdrawal(address(collateralMock), user1);
        address[] memory assets = new address[](1);
        assets[0] = address(collateralMock);
        (uint256[] memory pendingAmounts, uint32[] memory withdrawalTimes) =
            nexusYieldProxy.pendingWithdrawals(assets, user1);

        assertEq(pendingAmounts[0], pendingAmount);
        assertEq(withdrawalTimes[0], withdrawalTime);
        assertEq(previewFee, fee);
        assertEq(previewAmount, amount - fee);
        assertEq(pendingAmount, previewAmount);
        assertEq(withdrawalTime, block.timestamp + nexusYieldProxy.swapWaitingPeriod(address(collateralMock)));

        // try to withdraw => should fail
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.WithdrawalNotAvailable.selector, withdrawalTime));
        nexusYieldProxy.withdraw(address(collateralMock));

        vm.warp(block.timestamp + nexusYieldProxy.swapWaitingPeriod(address(collateralMock)));
        nexusYieldProxy.withdraw(address(collateralMock));
        assertEq(collateralMock.balanceOf(user1), amount - fee);
        vm.stopPrank();
    }

    function test_scheduleTwice() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        debtTokenProxy().approve(address(nexusYieldProxy), amount + fee);
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);

        (, uint32 withdrawalTime) = nexusYieldProxy.pendingWithdrawal(address(collateralMock), user1);

        vm.expectRevert(
            abi.encodeWithSelector(INexusYieldManagerFacet.WithdrawalAlreadyScheduled.selector, withdrawalTime)
        );
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);
    }

    function test_swapOutBalanceNotEnough() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.setPrivileged(user2, true);
        deal(address(collateralMock), user1, 100e18);
        deal(address(collateralMock), user2, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user2, 100e18);

        uint256 amount = 101e18;
        debtTokenProxy().approve(address(nexusYieldProxy), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManagerFacet.NotEnoughDebtToken.selector, debtTokenProxy().balanceOf(user2), amount
            )
        );
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManagerFacet.NotEnoughDebtToken.selector, debtTokenProxy().balanceOf(user2), amount
            )
        );
        nexusYieldProxy.swapOutPrivileged(address(collateralMock), user2, amount);

        vm.stopPrank();
    }

    function test_mintCapReached() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.setPrivileged(user1, true);
        deal(address(collateralMock), user1, 1000000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1000000e18);
        uint256 debtTokenMinted = nexusYieldProxy.debtTokenMinted(address(collateralMock));
        uint256 amountToMint = 1000000e18;
        uint256 debtTokenMintCap = nexusYieldProxy.debtTokenMintCap(address(collateralMock));
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManagerFacet.DebtTokenMintCapReached.selector,
                debtTokenMinted,
                amountToMint,
                debtTokenMintCap
            )
        );
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1000000e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManagerFacet.DebtTokenMintCapReached.selector,
                debtTokenMinted,
                amountToMint,
                debtTokenMintCap
            )
        );
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 1000000e18);
        vm.stopPrank();
    }

    function test_sunsetAsset() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.sunsetAsset(address(collateralMock));
        assertFalse(nexusYieldProxy.isAssetSupported(address(collateralMock)));
        vm.stopPrank();
    }

    function test_convertDebtTokenToAssetAmount() public {
        ERC20Mock coll1 = new mock6();
        ERC20Mock coll2 = new mock27();

        uint256 amount = nexusYieldProxy.convertDebtTokenToAssetAmount(address(coll1), 1e18);
        assertEq(amount, 1e6);

        amount = nexusYieldProxy.convertDebtTokenToAssetAmount(address(coll2), 1e18);
        assertEq(amount, 1e27);
    }

    function test_convertAssetToDebtTokenAmount() public {
        ERC20Mock coll1 = new mock6();
        ERC20Mock coll2 = new mock27();

        uint256 amount = nexusYieldProxy.convertAssetToDebtTokenAmount(address(coll1), 1e6);
        assertEq(amount, 1e18);

        amount = nexusYieldProxy.convertAssetToDebtTokenAmount(address(coll2), 1e27);
        assertEq(amount, 1e18);
    }

    function test_setAssetConfig() public {
        vm.startPrank(OWNER);
        uint256 feeIn = 100000;
        uint256 feeOut = 10;
        AssetConfig memory config = AssetConfig(
            priceFeedAggregatorProxy(),
            feeIn,
            feeOut,
            10000e18,
            1000e18,
            0,
            false,
            3 days,
            1.1e18,
            0.9e18,
            uint256(collateral.decimals())
        );
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.InvalidFee.selector, feeIn, feeOut));
        nexusYieldProxy.setAssetConfig(address(collateral), config);
        nexusYieldProxy.setAssetConfig(
            address(collateral),
            AssetConfig(
                priceFeedAggregatorProxy(),
                10,
                10,
                10000e18,
                1000e18,
                0,
                false,
                3 days,
                1.1e18,
                0.9e18,
                uint256(collateral.decimals())
            )
        );
        assertEq(nexusYieldProxy.feeIn(address(collateralMock)), 10);
        assertEq(nexusYieldProxy.feeOut(address(collateralMock)), 10);
        assertEq(nexusYieldProxy.debtTokenMintCap(address(collateralMock)), 10000e18);
        assertEq(nexusYieldProxy.dailyDebtTokenMintCap(address(collateralMock)), 1000e18);
        assertEq(address(nexusYieldProxy.oracle(address(collateralMock))), address(priceFeedAggregatorProxy()));
        assertFalse(nexusYieldProxy.isUsingOracle(address(collateralMock)));
        assertEq(nexusYieldProxy.swapWaitingPeriod(address(collateralMock)), 3 days);
        vm.stopPrank();
    }

    function test_isNotActive() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.pause();

        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        vm.expectRevert(INexusYieldManagerFacet.Paused.selector);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
    }

    function test_isNotPriviledge() public {
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        vm.expectRevert("NexusYieldManager: caller is not privileged");
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 100e18);
    }

    function test_assetNotSupport() public {
        ERC20Mock coll = new mock6();
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.AssetNotSupported.selector, address(coll)));
        nexusYieldProxy.swapIn(address(coll), user1, 1e18);
    }

    function test_zeroAddress() public {
        vm.expectRevert(INexusYieldManagerFacet.ZeroAddress.selector);
        nexusYieldProxy.swapIn(address(collateralMock), address(0), 100e18);
    }

    function test_amountTooSmall() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        uint256 amount = 1;
        uint256 feeAmount = amount * nexusYieldProxy.feeIn(address(collateralMock));
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.AmountTooSmall.selector, feeAmount));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
    }

    function test_oraclePriceLessThan1() public {
        _updateRoundData(
            RoundData({answer: 0.9e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy().fetchPrice(collateralMock), 0.9e18);

        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateral),
            AssetConfig(
                priceFeedAggregatorProxy(),
                10,
                10,
                10000e18,
                1000e18,
                0,
                true,
                3 days,
                1.1e18,
                0.9e18,
                uint256(collateral.decimals())
            )
        );

        uint256 amount = 100e18;
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
        (, uint256 previewFee) = nexusYieldProxy.previewSwapIn(address(collateralMock), amount);
        uint256 fee = amount * 9 / 10 * nexusYieldProxy.feeIn(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        assertEq(previewFee, fee);
        assertEq(debtTokenProxy().balanceOf(user1), 90e18 - fee);
    }

    function test_priceOutOfRange() public {
        _updateRoundData(
            RoundData({answer: 0.8e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy().fetchPrice(collateralMock), 0.8e18);

        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateral),
            AssetConfig(
                priceFeedAggregatorProxy(),
                10,
                10,
                10000e18,
                1000e18,
                0,
                true,
                3 days,
                1.1e18,
                0.9e18,
                uint256(collateral.decimals())
            )
        );

        uint256 amount = 100e18;
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.InvalidPrice.selector, 0.8e18));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);

        // price > 1.1
        _updateRoundData(
            RoundData({answer: 1.2e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy().fetchPrice(collateralMock), 1.2e18);

        amount = 100e18;
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManagerFacet.InvalidPrice.selector, 1.2e18));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
    }

    function test_permission() public {
        address someone = makeAddr("someone");
        vm.startPrank(someone);
        vm.expectRevert(
            "AccessControl: account 0x69979820b003b34127eadba93bd51caac2f768db is missing role 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e"
        );
        nexusYieldProxy.pause();

        vm.expectRevert(
            "AccessControl: account 0x69979820b003b34127eadba93bd51caac2f768db is missing role 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e"
        );
        nexusYieldProxy.resume();

        vm.expectRevert(
            "AccessControl: account 0x69979820b003b34127eadba93bd51caac2f768db is missing role 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e"
        );
        nexusYieldProxy.sunsetAsset(address(collateralMock));

        vm.expectRevert(
            "AccessControl: account 0x69979820b003b34127eadba93bd51caac2f768db is missing role 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e"
        );
        nexusYieldProxy.setPrivileged(user1, true);
        vm.stopPrank();
    }

    /**
     * utils
     */
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

    function _provideToSP(address caller, uint256 amount) internal {
        TroveBase.provideToSP(stabilityPoolProxy(), caller, amount);
    }

    function _withdrawFromSP(address caller, uint256 amount) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy(), caller, amount);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _claimCollateralGains(address caller) internal {
        vm.startPrank(caller);
        uint256[] memory collateralIndexes = new uint256[](1);
        collateralIndexes[0] = 0;
        stabilityPoolProxy().claimCollateralGains(caller, collateralIndexes);
        vm.stopPrank();
    }

    function _troveClaimOSHIReward(address caller) internal returns (uint256 amount) {
        vm.startPrank(caller);
        amount = troveManagerBeaconProxy.claimReward(caller);
    }

    function _spClaimReward(address caller) internal returns (uint256 amount) {
        vm.startPrank(caller);
        amount = stabilityPoolProxy().claimReward(caller);
    }

    function _stakeOSHIToRewardManager(address caller, uint256 amount, LockDuration lock) internal {
        vm.startPrank(caller);
        oshiTokenProxy().approve(address(rewardManager), amount);
        rewardManager.stake(amount, lock);
        vm.stopPrank();
    }

    function _unstakeOSHIFromRewardManager(address caller, uint256 amount) internal {
        vm.startPrank(caller);
        rewardManager.unstake(amount);
        vm.stopPrank();
    }

    function _claimsRewardManagerReward(address caller) internal {
        vm.startPrank(caller);
        rewardManager.claimReward();
        vm.stopPrank();
    }

    function _redeemCollateral(address caller, uint256 redemptionAmount) internal {
        uint256 price = troveManagerBeaconProxy.fetchPrice();
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount) =
            hintHelpers.getRedemptionHints(troveManagerBeaconProxy, redemptionAmount, price, 0);
        (address hintAddress,,) = hintHelpers.getApproxHint(troveManagerBeaconProxy, partialRedemptionHintNICR, 10, 42);

        (address upperPartialRedemptionHint, address lowerPartialRedemptionHint) =
            sortedTrovesBeaconProxy.findInsertPosition(partialRedemptionHintNICR, hintAddress, hintAddress);

        // redeem
        vm.startPrank(caller);
        troveManagerBeaconProxy.redeemCollateral(
            truncatedDebtAmount,
            firstRedemptionHint,
            upperPartialRedemptionHint,
            lowerPartialRedemptionHint,
            partialRedemptionHintNICR,
            0,
            maxFeePercentage
        );
    }

    function _recordUserStateBeforeToVar(RewardManagerVars memory vars) internal view {
        (vars.userCollBefore[0], vars.userDebtBefore[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollBefore[1], vars.userDebtBefore[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollBefore[2], vars.userDebtBefore[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollBefore[3], vars.userDebtBefore[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
        (vars.userCollBefore[4], vars.userDebtBefore[4]) = troveManagerBeaconProxy.getTroveCollAndDebt(user5);
        for (uint256 i; i < 5; ++i) {
            if (vars.userDebtBefore[i] < DEBT_GAS_COMPENSATION) {
                continue;
            } else {
                vars.userMintingFee[i] = (vars.userDebtBefore[i] - DEBT_GAS_COMPENSATION) * 5 / 1000;
            }
        }
    }

    function _recordUserStateAfterToVar(RewardManagerVars memory vars) internal view {
        (vars.userCollAfter[0], vars.userDebtAfter[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollAfter[1], vars.userDebtAfter[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollAfter[2], vars.userDebtAfter[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollAfter[3], vars.userDebtAfter[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
        (vars.userCollAfter[4], vars.userDebtAfter[4]) = troveManagerBeaconProxy.getTroveCollAndDebt(user5);
    }

    function _recordClaimableTroveRewardToVar(RewardManagerVars memory vars) internal view {
        vars.claimableTroveReward[0] = troveManagerBeaconProxy.claimableReward(user1);
        vars.claimableTroveReward[1] = troveManagerBeaconProxy.claimableReward(user2);
        vars.claimableTroveReward[2] = troveManagerBeaconProxy.claimableReward(user3);
        vars.claimableTroveReward[3] = troveManagerBeaconProxy.claimableReward(user4);
        vars.claimableTroveReward[4] = troveManagerBeaconProxy.claimableReward(user5);
    }
}
