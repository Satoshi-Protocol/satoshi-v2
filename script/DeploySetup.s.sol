// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@solidstate/contracts/access/access_control/IAccessControl.sol";
import { IERC2535DiamondCutInternal } from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";
import { Script, console } from "forge-std/Script.sol";

import { SatoshiXApp } from "../src/core/SatoshiXApp.sol";

import { BorrowerOperationsFacet } from "../src/core/facets/BorrowerOperationsFacet.sol";

import { CoreFacet } from "../src/core/facets/CoreFacet.sol";

import { IWETH } from "../src/core/helpers/interfaces/IWETH.sol";
import { IBorrowerOperationsFacet } from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import { ICoreFacet } from "../src/core/interfaces/ICoreFacet.sol";
import { ISatoshiXApp } from "../src/core/interfaces/ISatoshiXApp.sol";
import { ITroveManager } from "../src/core/interfaces/ITroveManager.sol";
import { VaultManager } from "../src/vault/VaultManager.sol";

import { CommunityIssuance } from "../src/OSHI/CommunityIssuance.sol";
import { RewardManager } from "../src/OSHI/RewardManager.sol";
import { ICommunityIssuance } from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import { IRewardManager } from "../src/OSHI/interfaces/IRewardManager.sol";

import { DebtToken } from "../src/core/DebtToken.sol";
import { DebtTokenWithLz } from "../src/core/DebtTokenWithLz.sol";
import { Initializer } from "../src/core/Initializer.sol";
import { IVaultManager } from "../src/vault/interfaces/IVaultManager.sol";

import { SortedTroves } from "../src/core/SortedTroves.sol";
import { TroveManager } from "../src/core/TroveManager.sol";
import { FactoryFacet } from "../src/core/facets/FactoryFacet.sol";
import { LiquidationFacet } from "../src/core/facets/LiquidationFacet.sol";
import { NexusYieldManagerFacet } from "../src/core/facets/NexusYieldManagerFacet.sol";
import { PriceFeedAggregatorFacet } from "../src/core/facets/PriceFeedAggregatorFacet.sol";
import { StabilityPoolFacet } from "../src/core/facets/StabilityPoolFacet.sol";

import { MultiCollateralHintHelpers } from "../src/core/helpers/MultiCollateralHintHelpers.sol";
import { IMultiCollateralHintHelpers } from "../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import { IDebtToken } from "../src/core/interfaces/IDebtToken.sol";
import { DeploymentParams, IFactoryFacet } from "../src/core/interfaces/IFactoryFacet.sol";
import { ILiquidationFacet } from "../src/core/interfaces/ILiquidationFacet.sol";
import { INexusYieldManagerFacet } from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import { IPriceFeedAggregatorFacet } from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";

import { ISortedTroves } from "../src/core/interfaces/ISortedTroves.sol";
import { IStabilityPoolFacet } from "../src/core/interfaces/IStabilityPoolFacet.sol";

import { AggregatorV3Interface } from "../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "../src/priceFeed/interfaces/IPriceFeed.sol";

import { OSHIToken } from "../src/OSHI/OSHIToken.sol";
import { IOSHIToken } from "../src/OSHI/interfaces/IOSHIToken.sol";

import { Config } from "../src/core/Config.sol";
import { GasPool } from "../src/core/GasPool.sol";

import { MultiTroveGetter } from "../src/core/helpers/MultiTroveGetter.sol";
import { SatoshiPeriphery } from "../src/core/helpers/SatoshiPeriphery.sol";

import { SwapRouter } from "../src/core/helpers/SwapRouter.sol";
import { TroveHelper } from "../src/core/helpers/TroveHelper.sol";

import { TroveManagerGetter } from "../src/core/helpers/TroveManagerGetter.sol";
import { IMultiTroveGetter } from "../src/core/helpers/interfaces/IMultiTroveGetter.sol";
import { ISatoshiPeriphery } from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import { ISwapRouter } from "../src/core/helpers/interfaces/ISwapRouter.sol";
import { ITroveHelper } from "../src/core/helpers/interfaces/ITroveHelper.sol";
import { ITroveManagerGetter } from "../src/core/helpers/interfaces/ITroveManagerGetter.sol";
import { IGasPool } from "../src/core/interfaces/IGasPool.sol";
import {
    DEBT_GAS_COMPENSATION,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    FEE_RECEIVER,
    FEE_RECEIVER,
    GUARDIAN,
    LZ_ENDPOINT,
    MIN_NET_DEBT,
    OWNER,
    SP_ALLOCATION,
    SP_CLAIM_START_TIME,
    SP_CLAIM_START_TIME,
    SP_REWARD_RATE,
    WETH_ADDRESS
} from "./DeploySetupConfig.s.sol";

contract Deployer is Script, IERC2535DiamondCutInternal {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address internal deployer;
    address internal owner;

    ISatoshiXApp internal satoshiXApp;
    IBorrowerOperationsFacet internal borrowerOperationsFacet;
    ICoreFacet internal coreFacet;
    IFactoryFacet internal factoryFacet;
    ILiquidationFacet internal liquidationFacet;
    IPriceFeedAggregatorFacet internal priceFeedAggregatorFacet;
    IStabilityPoolFacet internal stabilityPoolFacet;
    INexusYieldManagerFacet internal nexusYieldManagerFacet;

    Initializer internal initializer;

    IDebtToken internal debtToken;
    IRewardManager internal rewardManager;
    IVaultManager internal vaultManager;
    ICommunityIssuance internal communityIssuance;
    IOSHIToken internal oshiToken;
    IGasPool internal gasPool;

    IBeacon internal sortedTrovesBeacon;
    IBeacon internal troveManagerBeacon;

    ISatoshiPeriphery internal satoshiPeriphery;
    ISwapRouter internal swapRouter;

    IMultiCollateralHintHelpers internal hintHelpers;
    IMultiTroveGetter internal multiTroveGetter;
    ITroveHelper internal troveHelper;
    ITroveManagerGetter internal troveManagerGetter;

    function setUp() external {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);

        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        assert(OWNER_PRIVATE_KEY != 0);
        owner = vm.addr(OWNER_PRIVATE_KEY);
    }

    function run() external {
        _deploySortedTrovesBeacon();
        _deployTroveManagerBeacon();
        _deployInitializer();
        _deploySatoshiXApp();
        _deployAndCutFacets();
        _deployOSHIToken();
        _deployGasPool();
        _deployDebtToken(LZ_ENDPOINT, DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL);
        _deployCommunityIssuance();
        _deployRewardManager();
        _deployVaultManager();
        _deployPeriphery();
        _deploySwapRouter();
        _satoshiXAppInit();
        _deployHelpers();

        // set config
        _setConfigByOwner();

        // console.log all contracts
        _consoleAllContract();
    }

    function _deployPeriphery() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(satoshiPeriphery) == address(0)); // check if contract is not deployed
        assert(address(debtToken) != address(0)); // check if debtToken is deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed
        bytes memory data =
            abi.encodeCall(ISatoshiPeriphery.initialize, (IDebtToken(address(debtToken)), address(satoshiXApp), owner));
        address peripheryImpl = address(new SatoshiPeriphery());
        satoshiPeriphery = ISatoshiPeriphery(address(new ERC1967Proxy(peripheryImpl, data)));
        vm.stopBroadcast();
    }

    function _deploySwapRouter() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(swapRouter) == address(0)); // check if contract is not deployed
        assert(address(debtToken) != address(0)); // check if debtToken is deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed
        bytes memory data =
            abi.encodeCall(ISwapRouter.initialize, (IDebtToken(address(debtToken)), address(satoshiXApp), owner));
        address swapRouterImpl = address(new SwapRouter());
        swapRouter = ISwapRouter(address(new ERC1967Proxy(swapRouterImpl, data)));
        vm.stopBroadcast();
    }

    function _deploySatoshiXApp() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(satoshiXApp) == address(0)); // check if contract is not deployed
        satoshiXApp = ISatoshiXApp(payable(address(new SatoshiXApp())));

        vm.stopBroadcast();
    }

    function _deployAndCutFacets() internal {
        // deploy facets here
        address facetAddr;
        bytes4[] memory selectors;
        (facetAddr, selectors) = _deployCoreFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployBorrowerOperationsFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployFactoryFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployLiquidationFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployPriceFeedAggregatorFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployStabilityPoolFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployNexusYieldManagerFacet();
        _diamondCut(satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
    }

    function _deployBorrowerOperationsFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(borrowerOperationsFacet) == address(0)); // check if contract is not deployed
        borrowerOperationsFacet = IBorrowerOperationsFacet(address(new BorrowerOperationsFacet()));
        bytes4[] memory selectors = new bytes4[](19);
        selectors[0] = IBorrowerOperationsFacet.addColl.selector;
        selectors[1] = IBorrowerOperationsFacet.adjustTrove.selector;
        selectors[2] = IBorrowerOperationsFacet.checkRecoveryMode.selector;
        selectors[3] = IBorrowerOperationsFacet.closeTrove.selector;
        selectors[4] = IBorrowerOperationsFacet.fetchBalances.selector;
        selectors[5] = IBorrowerOperationsFacet.getCompositeDebt.selector;
        selectors[6] = IBorrowerOperationsFacet.getGlobalSystemBalances.selector;
        selectors[7] = IBorrowerOperationsFacet.getTCR.selector;
        selectors[8] = IBorrowerOperationsFacet.isApprovedDelegate.selector;
        selectors[9] = IBorrowerOperationsFacet.minNetDebt.selector;
        selectors[10] = IBorrowerOperationsFacet.openTrove.selector;
        selectors[11] = IBorrowerOperationsFacet.removeTroveManager.selector;
        selectors[12] = IBorrowerOperationsFacet.repayDebt.selector;
        selectors[13] = IBorrowerOperationsFacet.setDelegateApproval.selector;
        selectors[14] = IBorrowerOperationsFacet.setMinNetDebt.selector;
        selectors[15] = IBorrowerOperationsFacet.troveManagersData.selector;
        selectors[16] = IBorrowerOperationsFacet.withdrawColl.selector;
        selectors[17] = IBorrowerOperationsFacet.withdrawDebt.selector;
        selectors[18] = IBorrowerOperationsFacet.forceResetTM.selector;
        vm.stopBroadcast();
        return (address(borrowerOperationsFacet), selectors);
    }

    function _deployCoreFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(coreFacet) == address(0)); // check if contract is not deployed
        coreFacet = ICoreFacet(address(new CoreFacet()));
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = ICoreFacet.setFeeReceiver.selector;
        selectors[1] = ICoreFacet.setRewardManager.selector;
        selectors[2] = ICoreFacet.setPaused.selector;
        selectors[3] = ICoreFacet.feeReceiver.selector;
        selectors[4] = ICoreFacet.rewardManager.selector;
        selectors[5] = ICoreFacet.paused.selector;
        selectors[6] = ICoreFacet.startTime.selector;
        selectors[7] = ICoreFacet.debtToken.selector;
        selectors[8] = ICoreFacet.gasCompensation.selector;
        selectors[9] = ICoreFacet.sortedTrovesBeacon.selector;
        selectors[10] = ICoreFacet.troveManagerBeacon.selector;
        selectors[11] = ICoreFacet.communityIssuance.selector;
        vm.stopBroadcast();
        return (address(coreFacet), selectors);
    }

    function _deployFactoryFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(factoryFacet) == address(0)); // check if contract is not deployed
        factoryFacet = IFactoryFacet(address(new FactoryFacet()));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IFactoryFacet.deployNewInstance.selector;
        selectors[1] = IFactoryFacet.troveManagerCount.selector;
        selectors[2] = IFactoryFacet.troveManagers.selector;
        selectors[3] = IFactoryFacet.setTMRewardRate.selector;
        selectors[4] = IFactoryFacet.maxTMRewardRate.selector;
        vm.stopBroadcast();
        return (address(factoryFacet), selectors);
    }

    function _deployLiquidationFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(liquidationFacet) == address(0)); // check if contract is not deployed
        liquidationFacet = ILiquidationFacet(address(new LiquidationFacet()));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[1] = ILiquidationFacet.liquidate.selector;
        selectors[2] = ILiquidationFacet.liquidateTroves.selector;
        vm.stopBroadcast();
        return (address(liquidationFacet), selectors);
    }

    function _deployPriceFeedAggregatorFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(priceFeedAggregatorFacet) == address(0)); // check if contract is not deployed
        priceFeedAggregatorFacet = IPriceFeedAggregatorFacet(address(new PriceFeedAggregatorFacet()));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IPriceFeedAggregatorFacet.fetchPrice.selector;
        selectors[1] = IPriceFeedAggregatorFacet.fetchPriceUnsafe.selector;
        selectors[2] = IPriceFeedAggregatorFacet.setPriceFeed.selector;
        selectors[3] = IPriceFeedAggregatorFacet.oracleRecords.selector;
        vm.stopBroadcast();
        return (address(priceFeedAggregatorFacet), selectors);
    }

    function _deployStabilityPoolFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(stabilityPoolFacet) == address(0)); // check if contract is not deployed
        stabilityPoolFacet = IStabilityPoolFacet(address(new StabilityPoolFacet()));
        bytes4[] memory selectors = new bytes4[](25);
        selectors[0] = IStabilityPoolFacet.claimCollateralGains.selector;
        selectors[1] = IStabilityPoolFacet.provideToSP.selector;
        selectors[2] = IStabilityPoolFacet.startCollateralSunset.selector;
        selectors[3] = IStabilityPoolFacet.withdrawFromSP.selector;
        selectors[4] = IStabilityPoolFacet.accountDeposits.selector;
        selectors[5] = IStabilityPoolFacet.collateralGainsByDepositor.selector;
        selectors[6] = IStabilityPoolFacet.collateralTokens.selector;
        selectors[7] = IStabilityPoolFacet.currentEpoch.selector;
        selectors[8] = IStabilityPoolFacet.currentScale.selector;
        selectors[9] = IStabilityPoolFacet.depositSnapshots.selector;
        selectors[10] = IStabilityPoolFacet.depositSums.selector;
        selectors[11] = IStabilityPoolFacet.epochToScaleToG.selector;
        selectors[12] = IStabilityPoolFacet.epochToScaleToSums.selector;
        selectors[13] = IStabilityPoolFacet.getCompoundedDebtDeposit.selector;
        selectors[14] = IStabilityPoolFacet.getDepositorCollateralGain.selector;
        selectors[15] = IStabilityPoolFacet.getTotalDebtTokenDeposits.selector;
        selectors[16] = IStabilityPoolFacet.indexByCollateral.selector;
        selectors[17] = IStabilityPoolFacet.claimableReward.selector;
        selectors[18] = IStabilityPoolFacet.claimReward.selector;
        selectors[19] = IStabilityPoolFacet.setClaimStartTime.selector;
        selectors[20] = IStabilityPoolFacet.isClaimStart.selector;
        selectors[21] = IStabilityPoolFacet.rewardRate.selector;
        selectors[22] = IStabilityPoolFacet.setSPRewardRate.selector;
        selectors[23] = IStabilityPoolFacet.P.selector;
        selectors[24] = IStabilityPoolFacet.setRewardRate.selector;
        vm.stopBroadcast();
        return (address(stabilityPoolFacet), selectors);
    }

    function _deployNexusYieldManagerFacet() internal returns (address, bytes4[] memory) {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(nexusYieldManagerFacet) == address(0)); // check if contract is not deployed
        nexusYieldManagerFacet = INexusYieldManagerFacet(address(new NexusYieldManagerFacet()));
        bytes4[] memory selectors = new bytes4[](29);
        selectors[0] = INexusYieldManagerFacet.setAssetConfig.selector;
        selectors[1] = INexusYieldManagerFacet.sunsetAsset.selector;
        selectors[2] = INexusYieldManagerFacet.swapIn.selector;
        selectors[3] = INexusYieldManagerFacet.pause.selector;
        selectors[4] = INexusYieldManagerFacet.resume.selector;
        selectors[5] = INexusYieldManagerFacet.setPrivileged.selector;
        selectors[6] = INexusYieldManagerFacet.transferTokenToPrivilegedVault.selector;
        selectors[7] = INexusYieldManagerFacet.previewSwapOut.selector;
        selectors[8] = INexusYieldManagerFacet.previewSwapIn.selector;
        selectors[9] = INexusYieldManagerFacet.swapOutPrivileged.selector;
        selectors[10] = INexusYieldManagerFacet.swapInPrivileged.selector;
        selectors[11] = INexusYieldManagerFacet.scheduleSwapOut.selector;
        selectors[12] = INexusYieldManagerFacet.withdraw.selector;
        selectors[13] = INexusYieldManagerFacet.convertDebtTokenToAssetAmount.selector;
        selectors[14] = INexusYieldManagerFacet.convertAssetToDebtTokenAmount.selector;
        selectors[15] = INexusYieldManagerFacet.feeIn.selector;
        selectors[16] = INexusYieldManagerFacet.feeOut.selector;
        selectors[17] = INexusYieldManagerFacet.debtTokenMintCap.selector;
        selectors[18] = INexusYieldManagerFacet.dailyDebtTokenMintCap.selector;
        selectors[19] = INexusYieldManagerFacet.debtTokenMinted.selector;
        selectors[20] = INexusYieldManagerFacet.isUsingOracle.selector;
        selectors[21] = INexusYieldManagerFacet.swapWaitingPeriod.selector;
        selectors[22] = INexusYieldManagerFacet.debtTokenDailyMintCapRemain.selector;
        selectors[23] = INexusYieldManagerFacet.pendingWithdrawal.selector;
        selectors[24] = INexusYieldManagerFacet.pendingWithdrawals.selector;
        selectors[25] = INexusYieldManagerFacet.isNymPaused.selector;
        selectors[26] = INexusYieldManagerFacet.dailyMintCount.selector;
        selectors[27] = INexusYieldManagerFacet.isAssetSupported.selector;
        selectors[28] = INexusYieldManagerFacet.getAssetConfig.selector;
        vm.stopBroadcast();
        return (address(nexusYieldManagerFacet), selectors);
    }

    function _deployInitializer() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(initializer) == address(0)); // check if contract is not deployed
        initializer = new Initializer();
        vm.stopBroadcast();
    }

    function _deployRewardManager() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(rewardManager) == address(0)); // check if contract is not deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed
        assert(address(debtToken) != address(0)); // check if debtToken is deployed
        assert(address(oshiToken) != address(0)); // check if oshiToken is deployed
        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(
            IRewardManager.initialize,
            (owner, address(satoshiXApp), WETH_ADDRESS, address(debtToken), address(oshiToken))
        );
        rewardManager = IRewardManager(address(new ERC1967Proxy(address(rewardManagerImpl), data)));
        vm.stopBroadcast();
    }

    function _deployVaultManager() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(vaultManager) == address(0)); // check if contract is not deployed
        assert(address(debtToken) != address(0)); // check if debtToken is deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed
        address vaultManagerImpl = address(new VaultManager());
        bytes memory data = abi.encodeCall(IVaultManager.initialize, (address(debtToken), address(satoshiXApp), OWNER));
        vaultManager = IVaultManager(address(new ERC1967Proxy(address(vaultManagerImpl), data)));
        vm.stopBroadcast();
    }

    function _deployDebtToken(address endpoint, string memory debtTokenName, string memory debtTokenSymbol) internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(debtToken) == address(0)); // check if contract is not deployed
        assert(address(gasPool) != address(0)); // check if gasPool is deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed

        address debtTokenImpl;
        LZ_ENDPOINT == address(0)
            // if LZ_ENDPOINT is not set, deploy DebtToken
            ? debtTokenImpl = address(new DebtToken())
            // if LZ_ENDPOINT is set, deploy DebtTokenWithLz
            : debtTokenImpl = address(new DebtTokenWithLz(endpoint));

        bytes memory data = abi.encodeCall(
            IDebtToken.initialize,
            (debtTokenName, debtTokenSymbol, address(gasPool), address(satoshiXApp), owner, DEBT_GAS_COMPENSATION)
        );
        debtToken = IDebtToken(address(new ERC1967Proxy(address(debtTokenImpl), data)));
        vm.stopBroadcast();
    }

    function _deployCommunityIssuance() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(communityIssuance) == address(0)); // check if contract is not deployed
        assert(address(oshiToken) != address(0)); // check if oshiToken is deployed
        assert(address(satoshiXApp) != address(0)); // check if satoshiXApp is deployed
        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (owner, oshiToken, address(satoshiXApp)));
        communityIssuance = ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
        vm.stopBroadcast();
    }

    function _deployGasPool() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(gasPool == IGasPool(address(0))); // check if gas pool contract is not deployed
        gasPool = new GasPool();
        vm.stopBroadcast();
    }

    function _deploySortedTrovesBeacon() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(sortedTrovesBeacon) == address(0)); // check if contract is not deployed
        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl), owner);
        vm.stopBroadcast();
    }

    function _deployTroveManagerBeacon() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(troveManagerBeacon) == address(0)); // check if contract is not deployed
        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl), owner);
        vm.stopBroadcast();
    }

    function _deployOSHIToken() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(oshiToken) == address(0)); // check if contract is not deployed
        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, owner);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));
        vm.stopBroadcast();
    }

    function _diamondCut(
        ISatoshiXApp diamond,
        address target,
        IERC2535DiamondCutInternal.FacetCutAction action,
        bytes4[] memory selectors
    )
        internal
    {
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](1);
        IERC2535DiamondCutInternal.FacetCut memory facetCut;
        facetCut = IERC2535DiamondCutInternal.FacetCut({ target: target, action: action, selectors: selectors });
        facetCuts[0] = facetCut;

        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        diamond.diamondCut(facetCuts, address(0), "");
        vm.stopBroadcast();
    }

    function _satoshiXAppInit() internal {
        assert(address(satoshiXApp) != address(0));
        assert(address(initializer) != address(0));

        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Initializer.init.selector;
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: address(initializer),
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        assert(address(debtToken) != address(0));
        assert(address(rewardManager) != address(0));
        assert(address(communityIssuance) != address(0));
        assert(address(sortedTrovesBeacon) != address(0));
        assert(address(troveManagerBeacon) != address(0));
        assert(address(gasPool) != address(0));

        bytes memory _data = abi.encode(
            address(rewardManager),
            address(debtToken),
            address(communityIssuance),
            address(sortedTrovesBeacon),
            address(troveManagerBeacon),
            address(gasPool),
            OWNER,
            GUARDIAN,
            FEE_RECEIVER,
            MIN_NET_DEBT,
            DEBT_GAS_COMPENSATION
        );

        bytes memory data = abi.encodeWithSelector(Initializer.init.selector, _data);
        satoshiXApp.diamondCut(facetCuts, address(initializer), data);
        vm.stopBroadcast();
    }

    function _setConfigByOwner() internal {
        _setAuth();
        _setRewardManager(address(rewardManager));
        _setSPCommunityIssuanceAllocation();
        _setClaimStartTime(SP_CLAIM_START_TIME);
        _setSPRewardRate(SP_REWARD_RATE);
    }

    function _setAuth() internal {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        debtToken.rely(address(satoshiXApp));
        vm.stopBroadcast();
    }

    function _setRewardManager(address _rewardManager) internal {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        ICoreFacet(address(satoshiXApp)).setRewardManager(_rewardManager);
        vm.stopBroadcast();
    }

    function _setSPCommunityIssuanceAllocation() internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(satoshiXApp);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = SP_ALLOCATION;
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        communityIssuance.setAllocated(_recipients, _amounts);
        vm.stopBroadcast();
    }

    function _setClaimStartTime(uint32 _claimStartTime) internal {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        IStabilityPoolFacet stabilityPoolProxy = IStabilityPoolFacet(address(satoshiXApp));
        stabilityPoolProxy.setClaimStartTime(_claimStartTime);
        vm.stopBroadcast();
    }

    function _setSPRewardRate(uint128 _rewardRate) internal {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        IStabilityPoolFacet stabilityPool = IStabilityPoolFacet(address(satoshiXApp));
        stabilityPool.setSPRewardRate(_rewardRate);
        vm.stopBroadcast();
    }

    function _deployHelpers() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        assert(address(hintHelpers) == address(0)); // check if contract is not deployed
        assert(address(multiTroveGetter) == address(0)); // check if contract is not deployed
        assert(address(troveHelper) == address(0)); // check if contract is not deployed
        assert(address(troveManagerGetter) == address(0)); // check if contract is not deployed

        hintHelpers = IMultiCollateralHintHelpers(address(new MultiCollateralHintHelpers(address(satoshiXApp))));
        multiTroveGetter = IMultiTroveGetter(address(new MultiTroveGetter()));
        troveHelper = ITroveHelper(address(new TroveHelper()));
        troveManagerGetter = ITroveManagerGetter(address(new TroveManagerGetter(address(satoshiXApp))));
        vm.stopBroadcast();
    }

    function _consoleAllContract() internal view {
        console.log("deployer:", deployer);
        console.log("satoshiXApp", address(satoshiXApp));
        console.log("borrowerOperationsFacet", address(borrowerOperationsFacet));
        console.log("coreFacet", address(coreFacet));
        console.log("factoryFacet", address(factoryFacet));
        console.log("liquidationFacet", address(liquidationFacet));
        console.log("priceFeedAggregatorFacet", address(priceFeedAggregatorFacet));
        console.log("stabilityPoolFacet", address(stabilityPoolFacet));
        console.log("nexusYieldManagerFacet", address(nexusYieldManagerFacet));
        console.log("initializer", address(initializer));
        console.log("satoshiPeriphery", address(satoshiPeriphery));
        console.log("gasPool", address(gasPool));
        console.log("debtToken", address(debtToken));
        console.log("communityIssuance", address(communityIssuance));
        console.log("oshiToken", address(oshiToken));
        console.log("sortedTrovesBeacon", address(sortedTrovesBeacon));
        console.log("troveManagerBeacon", address(troveManagerBeacon));
        console.log("rewardManager", address(rewardManager));
        console.log("vaultManager", address(vaultManager));
        console.log("oshiToken", address(oshiToken));
        console.log("communityIssuance", address(communityIssuance));
        console.log("hintHelpers", address(hintHelpers));
        console.log("multiTroveGetter", address(multiTroveGetter));
        console.log("troveHelper", address(troveHelper));
        console.log("troveManagerGetter", address(troveManagerGetter));
    }
}
