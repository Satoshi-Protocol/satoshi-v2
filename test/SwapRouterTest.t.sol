// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CommunityIssuance } from "../src/OSHI/CommunityIssuance.sol";

import { OSHIToken } from "../src/OSHI/OSHIToken.sol";
import { RewardManager } from "../src/OSHI/RewardManager.sol";
import { ICommunityIssuance } from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import { IOSHIToken } from "../src/OSHI/interfaces/IOSHIToken.sol";
import { IRewardManager, LockDuration } from "../src/OSHI/interfaces/IRewardManager.sol";
import { Config } from "../src/core/Config.sol";

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
import { IBorrowerOperationsFacet } from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ICoreFacet } from "../src/core/interfaces/ICoreFacet.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { DeploymentParams, IFactoryFacet } from "../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../src/core/interfaces/ILiquidationFacet.sol";
import { AssetConfig, INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import { ISatoshiXApp } from "../src/core/interfaces/ISatoshiXApp.sol";

import { ISwapRouter, LzSendParam } from "../src/core/helpers/interfaces/ISwapRouter.sol";
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
import { console2 } from "forge-std/console2.sol";

contract mock6 is ERC20Mock {
    constructor() ERC20Mock("MOCK", "MOCK") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract mock27 is ERC20Mock {
    constructor() ERC20Mock("MOCK", "MOCK") { }

    function decimals() public pure override returns (uint8) {
        return 27;
    }
}

contract SwapRouterTest is DeployBase, TroveBase {
    using Math for uint256;

    uint256 maxFeePercentage = 0.05e18; // 5%
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
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
        collateral = ERC20Mock(address(collateralMock));
        nexusYieldProxy = getNexusYieldProxy();

        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateral), AssetConfig(10, 10, 10_000e18, 1000e18, 0, 3 days, 1.1e18, 0.9e18, false)
        );
        debtTokenProxy().rely(address(nexusYieldProxy));
        rewardManagerProxy().setWhitelistCaller(address(nexusYieldProxy), true);
        vm.stopPrank();
    }

    function test_swapInCrossChain_byRouter() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.setPrivileged(user2, true);
        deal(address(collateralMock), user1, 100e18);
        deal(address(collateralMock), user2, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(swapRouter), 100e18);
        swapRouter.swapInCrossChain(address(collateralMock), 100e18, user1, LzSendParam(0, "", MessagingFee(0, 0)));
        vm.stopPrank();
        uint256 fee = 100e18 * nexusYieldProxy.feeIn(address(collateralMock)) / Config.BASIS_POINTS_DIVISOR;
        assertEq(debtTokenProxy().balanceOf(user1), 100e18 - fee);

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
