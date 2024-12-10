// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IERC2535DiamondCutInternal} from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {ISatoshiXApp} from "../src/core/interfaces/ISatoshiXApp.sol";
import {BorrowerOperationsFacet} from "../src/core/facets/BorrowerOperationsFacet.sol";
import {IBorrowerOperationsFacet} from "../src/core/interfaces/IBorrowerOperationsFacet.sol";
import {CoreFacet} from "../src/core/facets/CoreFacet.sol";
import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {ITroveManager} from "../src/core/interfaces/ITroveManager.sol";

import {FactoryFacet} from "../src/core/facets/FactoryFacet.sol";
import {IFactoryFacet, DeploymentParams} from "../src/core/interfaces/IFactoryFacet.sol";
import {LiquidationFacet} from "../src/core/facets/LiquidationFacet.sol";
import {ILiquidationFacet} from "../src/core/interfaces/ILiquidationFacet.sol";
import {PriceFeedAggregatorFacet} from "../src/core/facets/PriceFeedAggregatorFacet.sol";
import {IPriceFeedAggregatorFacet} from "../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import {StabilityPoolFacet} from "../src/core/facets/StabilityPoolFacet.sol";
import {IStabilityPoolFacet} from "../src/core/interfaces/IStabilityPoolFacet.sol";
import {INexusYieldManagerFacet} from "../src/core/interfaces/INexusYieldManagerFacet.sol";
import {NexusYieldManagerFacet} from "../src/core/facets/NexusYieldManagerFacet.sol";
import {Initializer} from "../src/core/Initializer.sol";
import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import {IRewardManager} from "../src/OSHI/interfaces/IRewardManager.sol";
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
import {MultiCollateralHintHelpers} from "../src/core/helpers/MultiCollateralHintHelpers.sol";
import {IMultiCollateralHintHelpers} from "../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";

import {IOSHIToken} from "../src/OSHI/interfaces/IOSHIToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {ISatoshiPeriphery} from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/core/helpers/SatoshiPeriphery.sol";
import {IWETH} from "../src/core/helpers/interfaces/IWETH.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {IGasPool} from "../src/core/interfaces/IGasPool.sol";
import {Config} from "../src/core/Config.sol";
import "./configs/Config.arb-sepolia.sol";

contract Deployer is Script, IERC2535DiamondCutInternal {
    IWETH weth;
    address public LZ_ENDPOINT;
    uint256 public constant TOTAL_FACETS = 7;

    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public DEPLOYER;
    address public OWNER;

    // XApp
    ISatoshiXApp internal satoshiXApp;

    // Facets
    IBorrowerOperationsFacet internal borrowerOperationsFacet;
    ICoreFacet internal coreFacet;
    IFactoryFacet internal factoryFacet;
    ILiquidationFacet internal liquidationFacet;
    IPriceFeedAggregatorFacet internal priceFeedAggregatorFacet;
    IStabilityPoolFacet internal stabilityPoolFacet;
    INexusYieldManagerFacet internal nexusYieldManagerFacet;

    // Initializer
    Initializer internal initializer;

    // Core contracts 
    ISatoshiPeriphery internal satoshiPeriphery;
    IGasPool internal gasPool;
    IDebtToken internal debtToken;
    IRewardManager internal rewardManager;
    ICommunityIssuance internal communityIssuance;
    IOSHIToken internal oshiToken;
    IBeacon internal sortedTrovesBeacon;
    IBeacon internal troveManagerBeacon;

    function consoleAllContract() internal {
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
        console.log("rewardManager", address(rewardManager));
        console.log("communityIssuance", address(communityIssuance));
        console.log("oshiToken", address(oshiToken));
        console.log("sortedTrovesBeacon", address(sortedTrovesBeacon));
        console.log("troveManagerBeacon", address(troveManagerBeacon));
        console.log("rewardManager", address(rewardManager));
        console.log("oshiToken", address(oshiToken));
        console.log("communityIssuance", address(communityIssuance));
    }


    function _setContracts(address deployer) internal {
        vm.startBroadcast(deployer);
        ICoreFacet core = ICoreFacet(address(satoshiXApp));
        core.setRewardManager(address(rewardManager));
        core.setFeeReceiver(OWNER);
        vm.stopBroadcast();
    }

    function _deployPeriphery(address deployer) internal {
        vm.startBroadcast(deployer);
        bytes memory data = abi.encodeCall(ISatoshiPeriphery.initialize, (DebtToken(address(debtToken)), address(satoshiXApp), deployer));
        address peripheryImpl = address(new SatoshiPeriphery());
        satoshiPeriphery = ISatoshiPeriphery(address(new ERC1967Proxy(peripheryImpl, data)));
        vm.stopBroadcast();
    }

    function _deploySatoshiXApp(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(satoshiXApp) == address(0)); // check if contract is not deployed
        satoshiXApp = ISatoshiXApp(payable(address(new SatoshiXApp())));

        vm.stopBroadcast();
    }

    function _deployAndCutFacets(address deployer) internal {
        // deploy facets here
        address facetAddr;
        bytes4[] memory selectors;
        (facetAddr, selectors) = _deployBorrowerOperationsFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployCoreFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployFactoryFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployLiquidationFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployPriceFeedAggregatorFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployStabilityPoolFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
        (facetAddr, selectors) = _deployNexusYieldManagerFacet(deployer);
        _diamondCut(deployer, satoshiXApp, facetAddr, IERC2535DiamondCutInternal.FacetCutAction.ADD, selectors);
    }

    function _deployBorrowerOperationsFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
        assert(address(borrowerOperationsFacet) == address(0)); // check if contract is not deployed
        borrowerOperationsFacet = IBorrowerOperationsFacet(address(new BorrowerOperationsFacet()));
        bytes4[] memory selectors = new bytes4[](18);
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
        vm.stopBroadcast();
        return (address(borrowerOperationsFacet), selectors);
    }

    function _deployCoreFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
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

    function _deployFactoryFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
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

    function _deployLiquidationFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
        assert(address(liquidationFacet) == address(0)); // check if contract is not deployed
        liquidationFacet = ILiquidationFacet(address(new LiquidationFacet()));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[1] = ILiquidationFacet.liquidate.selector;
        selectors[2] = ILiquidationFacet.liquidateTroves.selector;
        vm.stopBroadcast();
        return (address(liquidationFacet), selectors);
    }

    function _deployPriceFeedAggregatorFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
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

    function _deployStabilityPoolFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
        assert(address(stabilityPoolFacet) == address(0)); // check if contract is not deployed
        stabilityPoolFacet = IStabilityPoolFacet(address(new StabilityPoolFacet()));
        bytes4[] memory selectors = new bytes4[](23);
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
        vm.stopBroadcast();
        return (address(stabilityPoolFacet), selectors);
    }

    function _deployNexusYieldManagerFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startBroadcast(deployer);
        assert(address(nexusYieldManagerFacet) == address(0)); // check if contract is not deployed
        nexusYieldManagerFacet = INexusYieldManagerFacet(address(new NexusYieldManagerFacet()));
        bytes4[] memory selectors = new bytes4[](26);
        selectors[0] = INexusYieldManagerFacet.setAssetConfig.selector;
        selectors[1] = INexusYieldManagerFacet.sunsetAsset.selector;
        selectors[2] = INexusYieldManagerFacet.swapIn.selector;
        selectors[3] = INexusYieldManagerFacet.pause.selector;
        selectors[4] = INexusYieldManagerFacet.resume.selector;
        selectors[5] = INexusYieldManagerFacet.setPrivileged.selector;
        selectors[6] = INexusYieldManagerFacet.transerTokenToPrivilegedVault.selector;
        selectors[7] = INexusYieldManagerFacet.previewSwapOut.selector;
        selectors[8] = INexusYieldManagerFacet.previewSwapIn.selector;
        selectors[9] = INexusYieldManagerFacet.swapOutPrivileged.selector;
        selectors[10] = INexusYieldManagerFacet.swapInPrivileged.selector;
        selectors[11] = INexusYieldManagerFacet.scheduleSwapOut.selector;
        selectors[12] = INexusYieldManagerFacet.withdraw.selector;
        selectors[13] = INexusYieldManagerFacet.convertDebtTokenToAssetAmount.selector;
        selectors[14] = INexusYieldManagerFacet.convertAssetToDebtTokenAmount.selector;
        selectors[15] = INexusYieldManagerFacet.oracle.selector;
        selectors[16] = INexusYieldManagerFacet.feeIn.selector;
        selectors[17] = INexusYieldManagerFacet.feeOut.selector;
        selectors[18] = INexusYieldManagerFacet.debtTokenMintCap.selector;
        selectors[19] = INexusYieldManagerFacet.dailyDebtTokenMintCap.selector;
        selectors[20] = INexusYieldManagerFacet.debtTokenMinted.selector;
        selectors[21] = INexusYieldManagerFacet.isUsingOracle.selector;
        selectors[22] = INexusYieldManagerFacet.swapWaitingPeriod.selector;
        selectors[23] = INexusYieldManagerFacet.debtTokenDailyMintCapRemain.selector;
        selectors[24] = INexusYieldManagerFacet.pendingWithdrawal.selector;
        selectors[25] = INexusYieldManagerFacet.pendingWithdrawals.selector;
        vm.stopBroadcast();
        return (address(stabilityPoolFacet), selectors);
    }

    function _deployInitializer(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(initializer) == address(0)); // check if contract is not deployed
        initializer = new Initializer();
        vm.stopBroadcast();
    }

    function _deployRewardManager(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(rewardManager) == address(0)); // check if contract is not deployed
        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(IRewardManager.initialize, (OWNER));
        rewardManager = IRewardManager(address(new ERC1967Proxy(address(rewardManagerImpl), data)));
        vm.stopBroadcast();
        vm.startBroadcast(OWNER);
        rewardManager.setAddresses(
            address(satoshiXApp),
            weth,
            debtToken,
            oshiToken
        );
        vm.stopBroadcast();
    }

    function _deployDebtToken(address deployer) internal {
        EndpointV2Mock endpointMock;
        uint32 eid = 1;
        endpointMock = new EndpointV2Mock(eid, address(this));

        vm.startBroadcast(deployer);
        assert(address(debtToken) == address(0)); // check if contract is not deployed
        address debtTokenImpl = address(new DebtToken(address(endpointMock)));
        bytes memory data =
            abi.encodeCall(IDebtToken.initialize, (Config.DEBT_TOKEN_NAME, Config.DEBT_TOKEN_SYMBOL, address(gasPool), address(satoshiXApp), OWNER));
        debtToken = IDebtToken(address(new ERC1967Proxy(address(debtTokenImpl), data)));
        vm.stopBroadcast();
    }

    function _deployCommunityIssuance(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(communityIssuance) == address(0)); // check if contract is not deployed
        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (OWNER, oshiToken, address(satoshiXApp)));
        communityIssuance = ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
        vm.stopBroadcast();
    }

    function _deploySortedTrovesBeacon(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(sortedTrovesBeacon) == address(0)); // check if contract is not deployed
        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl), OWNER);
        vm.stopBroadcast();
    }

    function _deployTroveManagerBeacon(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(troveManagerBeacon) == address(0)); // check if contract is not deployed
        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl), OWNER);
        vm.stopBroadcast();
    }

    function _deployOSHIToken(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(address(oshiToken) == address(0)); // check if contract is not deployed
        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, OWNER);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));
        vm.stopBroadcast();
    }

    function _diamondCut(
        address deployer,
        ISatoshiXApp diamond,
        address target,
        IERC2535DiamondCutInternal.FacetCutAction action,
        bytes4[] memory selectors
    ) internal {
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](1);
        IERC2535DiamondCutInternal.FacetCut memory facetCut;
        facetCut = IERC2535DiamondCutInternal.FacetCut({target: target, action: action, selectors: selectors});
        facetCuts[0] = facetCut;

        vm.startBroadcast(deployer);
        diamond.diamondCut(facetCuts, address(0), "");
        vm.stopBroadcast();
    }

    function _satoshiXAppInit(address deployer) internal {
        assert(address(satoshiXApp) != address(0));
        assert(address(initializer) != address(0));

        vm.startBroadcast(deployer);
        IERC2535DiamondCutInternal.FacetCut[] memory facetCuts = new IERC2535DiamondCutInternal.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Initializer.init.selector;
        facetCuts[0] = IERC2535DiamondCutInternal.FacetCut({
            target: address(initializer),
            action: IERC2535DiamondCutInternal.FacetCutAction.ADD,
            selectors: selectors
        });

        bytes memory _data = abi.encode(
            address(rewardManager),
            address(debtToken),
            address(communityIssuance),
            address(sortedTrovesBeacon),
            address(troveManagerBeacon)
        );

        bytes memory data = abi.encodeWithSelector(Initializer.init.selector, _data);
        satoshiXApp.diamondCut(facetCuts, address(initializer), data);
        vm.stopBroadcast();
    }

    function _setPriceFeedToPriceFeedAggregatorProxy(address owner, IERC20 collateral, IPriceFeed priceFeed) internal {
        vm.startBroadcast(owner);
        IPriceFeedAggregatorFacet(address(satoshiXApp)).setPriceFeed(collateral, priceFeed);
        vm.stopBroadcast();
    }


    function _registerTroveManager(address owner, ITroveManager _troveManager) internal {
        vm.startBroadcast(owner);
        rewardManager.registerTroveManager(_troveManager);
        vm.stopBroadcast();
    }

    function _setConfigByOwner(address owner, ITroveManager troveManagerBeaconProxy) internal {
        // set allocation for the stability pool
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(satoshiXApp);
        uint256[] memory _amount = new uint256[](1);
        _amount[0] = Config.SP_ALLOCATION;
        // _setRewardManager(owner, address(rewardManagerProxy));
        _setTMCommunityIssuanceAllocation(owner, troveManagerBeaconProxy);
        _setSPCommunityIssuanceAllocation(owner);
        // _setAddress(owner, address(satoshiXApp), weth, address(debtToken), address(oshiToken));
        _registerTroveManager(owner, troveManagerBeaconProxy);
        _setClaimStartTime(owner, Config.SP_CLAIM_START_TIME);
        _setSPRewardRate(owner);
        _setTMRewardRate(owner, troveManagerBeaconProxy);
    }

    // function _setAddress(
    //     address owner,
    //     IBorrowerOperations _borrowerOperations,
    //     IWETH _weth,
    //     IDebtToken _debtToken,
    //     IOSHIToken _oshiToken
    // ) internal {
    //     vm.startBroadcast(owner);
    //     rewardManager.setAddresses(_borrowerOperations, _weth, _debtToken, _oshiToken);
    //     vm.stopBroadcast();
    // }

    function _setTMCommunityIssuanceAllocation(address owner, ITroveManager troveManagerBeaconProxy) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(troveManagerBeaconProxy);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = Config.TM_ALLOCATION;
        vm.startBroadcast(owner);
        communityIssuance.setAllocated(_recipients, _amounts);
        vm.stopBroadcast();
    }

    function _setSPCommunityIssuanceAllocation(address owner) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(satoshiXApp);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = Config.SP_ALLOCATION;
        vm.startBroadcast(owner);
        communityIssuance.setAllocated(_recipients, _amounts);
        vm.stopBroadcast();
    }

    function _setTMRewardRate(address owner, ITroveManager troveManagerBeaconProxy) internal {
        vm.startBroadcast(owner);
        uint128[] memory numerator = new uint128[](2);
        numerator[0] = 0;
        numerator[1] = 0;
        IFactoryFacet factoryProxy = IFactoryFacet(address(satoshiXApp));
        factoryProxy.setTMRewardRate(numerator, 1);
        // assertEq(troveManagerBeaconProxy.rewardRate(), factoryProxy.maxRewardRate());
        vm.stopBroadcast();
    }

    function _setSPRewardRate(address owner) internal {
        vm.startBroadcast(owner);
        IStabilityPoolFacet stabilityPoolProxy = IStabilityPoolFacet(address(satoshiXApp));
        stabilityPoolProxy.setSPRewardRate(Config.SP_MAX_REWARD_RATE);
        vm.stopBroadcast();
    }

    function _setClaimStartTime(address owner, uint32 _claimStartTime) internal {
        vm.startBroadcast(owner);
        IStabilityPoolFacet stabilityPoolProxy = IStabilityPoolFacet(address(satoshiXApp));
        stabilityPoolProxy.setClaimStartTime(_claimStartTime);
        vm.stopBroadcast();
    }

    function _deployHintHelpers(address deployer) internal returns (address) {
        vm.startBroadcast(deployer);

        address hintHelpersAddr = address(new MultiCollateralHintHelpers(address(satoshiXApp)));
        vm.stopBroadcast();

        return hintHelpersAddr;
    }

    function _deployGasPool(address deployer) internal {
        vm.startBroadcast(deployer);
        assert(gasPool == IGasPool(address(0))); // check if gas pool contract is not deployed
        gasPool = new GasPool();
        vm.stopBroadcast();
    }


    function assertContractAddressHasCode(address contractAddress) public {
        // Check if the contract address has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(contractAddress)
        }

        // Assert that the code size is greater than 0
        if(codeSize == 0) {
            console.log("The address does not contain a contract.");
        }
    }
}
