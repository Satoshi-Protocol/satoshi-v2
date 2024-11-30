// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC2535DiamondCutInternal} from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {SatoshiXApp} from "../../src/core/SatoshiXApp.sol";
import {ISatoshiXApp} from "../../src/core/interfaces/ISatoshiXApp.sol";
import {BorrowerOperationsFacet} from "../../src/core/facets/BorrowerOperationsFacet.sol";
import {IBorrowerOperationsFacet} from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import {CoreFacet} from "../../src/core/facets/CoreFacet.sol";
import {ICoreFacet} from "../../src/core/interfaces/ICoreFacet.sol";
import {FactoryFacet} from "../../src/core/facets/FactoryFacet.sol";
import {IFactoryFacet} from "../../src/core/interfaces/IFactoryFacet.sol";
import {LiquidationFacet} from "../../src/core/facets/LiquidationFacet.sol";
import {ILiquidationFacet} from "../../src/core/interfaces/ILiquidationFacet.sol";
import {PriceFeedAggregatorFacet} from "../../src/core/facets/PriceFeedAggregatorFacet.sol";
import {IPriceFeedAggregatorFacet} from "../../src/core/interfaces/IPriceFeedAggregatorFacet.sol";
import {StabilityPoolFacet} from "../../src/core/facets/StabilityPoolFacet.sol";
import {IStabilityPoolFacet} from "../../src/core/interfaces/IStabilityPoolFacet.sol";
import {INexusYieldManagerFacet} from "../../src/core/interfaces/INexusYieldManagerFacet.sol";
import {NexusYieldManagerFacet} from "../../src/core/facets/NexusYieldManagerFacet.sol";
import {Initializer} from "../../src/core/Initializer.sol";
import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";

import {IRewardManager} from "../../src/OSHI/interfaces/IRewardManager.sol";
import {RewardManager} from "../../src/OSHI/RewardManager.sol";
import {IDebtToken} from "../../src/core/interfaces/IDebtToken.sol";
import {DebtToken} from "../../src/core/DebtToken.sol";
import {ICommunityIssuance} from "../../src/OSHI/interfaces/ICommunityIssuance.sol";
import {CommunityIssuance} from "../../src/OSHI/CommunityIssuance.sol";
import {SortedTroves} from "../../src/core/SortedTroves.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {DEPLOYER, OWNER, DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL} from "../TestConfig.sol";

import {IOSHIToken} from "../../src/OSHI/interfaces/IOSHIToken.sol";
import {OSHIToken} from "../../src/OSHI/OSHIToken.sol";
import {ISatoshiPeriphery} from "../../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../../src/core/helpers/SatoshiPeriphery.sol";
import {IWETH} from "../../src/core/helpers/interfaces/IWETH.sol";
import {WETH9} from "../mocks/WETH9.sol";

abstract contract DeployBase is Test {
    IWETH weth;
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
    ICommunityIssuance internal communityIssuance;
    IOSHIToken internal oshiToken;

    IBeacon internal sortedTrovesBeacon;
    IBeacon internal troveManagerBeacon;

    ISatoshiPeriphery internal satoshiPeriphery;

    function setUp() public virtual {
        _deployWETH(DEPLOYER);
        _deploySortedTrovesBeacon(DEPLOYER);
        _deploySatoshiXApp(DEPLOYER);
        _deployTroveManagerBeacon(DEPLOYER);
        _deployAndCutFacets(DEPLOYER);
        _deployOSHIToken(DEPLOYER);
        _deployDebtToken(DEPLOYER);
        _deployCommunityIssuance(DEPLOYER);
        _deployInitializer(DEPLOYER);
        _deployRewardManager(DEPLOYER);
        _deployPeriphery(DEPLOYER);
        _setContracts(DEPLOYER);
    }

    function _setContracts(address deployer) internal {
        vm.startPrank(deployer);
        ICoreFacet core = ICoreFacet(address(satoshiXApp));
        core.setRewardManager(address(rewardManager));
        core.setFeeReceiver(OWNER);
        vm.stopPrank();
    }

    function _deployPeriphery(address deployer) internal {
        vm.startPrank(deployer);
        bytes memory data = abi.encodeCall(ISatoshiPeriphery.initialize, (DebtToken(address(debtToken)), address(satoshiXApp), deployer));
        address peripheryImpl = address(new SatoshiPeriphery());
        satoshiPeriphery = ISatoshiPeriphery(address(new ERC1967Proxy(peripheryImpl, data)));
        vm.stopPrank();
    }

    function _deploySatoshiXApp(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(satoshiXApp) == address(0)); // check if contract is not deployed
        satoshiXApp = ISatoshiXApp(payable(address(new SatoshiXApp())));

        vm.stopPrank();
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
        vm.startPrank(deployer);
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
        vm.stopPrank();
        return (address(borrowerOperationsFacet), selectors);
    }

    function _deployCoreFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
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
        vm.stopPrank();
        return (address(coreFacet), selectors);
    }

    function _deployFactoryFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(factoryFacet) == address(0)); // check if contract is not deployed
        factoryFacet = IFactoryFacet(address(new FactoryFacet()));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IFactoryFacet.deployNewInstance.selector;
        selectors[1] = IFactoryFacet.troveManagerCount.selector;
        selectors[2] = IFactoryFacet.troveManagers.selector;
        selectors[3] = IFactoryFacet.setTMRewardRate.selector;
        selectors[4] = IFactoryFacet.maxTMRewardRate.selector;
        vm.stopPrank();
        return (address(factoryFacet), selectors);
    }

    function _deployLiquidationFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(liquidationFacet) == address(0)); // check if contract is not deployed
        liquidationFacet = ILiquidationFacet(address(new LiquidationFacet()));
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = ILiquidationFacet.batchLiquidateTroves.selector;
        selectors[1] = ILiquidationFacet.liquidate.selector;
        selectors[2] = ILiquidationFacet.liquidateTroves.selector;
        vm.stopPrank();
        return (address(liquidationFacet), selectors);
    }

    function _deployPriceFeedAggregatorFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(priceFeedAggregatorFacet) == address(0)); // check if contract is not deployed
        priceFeedAggregatorFacet = IPriceFeedAggregatorFacet(address(new PriceFeedAggregatorFacet()));
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IPriceFeedAggregatorFacet.fetchPrice.selector;
        selectors[1] = IPriceFeedAggregatorFacet.fetchPriceUnsafe.selector;
        selectors[2] = IPriceFeedAggregatorFacet.setPriceFeed.selector;
        selectors[3] = IPriceFeedAggregatorFacet.oracleRecords.selector;
        vm.stopPrank();
        return (address(priceFeedAggregatorFacet), selectors);
    }

    function _deployStabilityPoolFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
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
        vm.stopPrank();
        return (address(stabilityPoolFacet), selectors);
    }

    function _deployNexusYieldManagerFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
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
        vm.stopPrank();
        return (address(stabilityPoolFacet), selectors);
    }

    function _deployInitializer(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(initializer) == address(0)); // check if contract is not deployed
        initializer = new Initializer();
        vm.stopPrank();
    }

    function _deployRewardManager(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(rewardManager) == address(0)); // check if contract is not deployed
        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(IRewardManager.initialize, (OWNER));
        rewardManager = IRewardManager(address(new ERC1967Proxy(address(rewardManagerImpl), data)));
        vm.stopPrank();
        vm.startPrank(OWNER);
        rewardManager.setAddresses(
            address(satoshiXApp),
            weth,
            debtToken,
            oshiToken
        );
        vm.stopPrank();
    }

    function _deployDebtToken(address deployer) internal {
        EndpointV2Mock endpointMock;
        uint32 eid = 1;
        endpointMock = new EndpointV2Mock(eid, address(this));

        vm.startPrank(deployer);
        assert(address(debtToken) == address(0)); // check if contract is not deployed
        address debtTokenImpl = address(new DebtToken(address(endpointMock)));
        bytes memory data =
            abi.encodeCall(IDebtToken.initialize, (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, address(satoshiXApp), OWNER));
        debtToken = IDebtToken(address(new ERC1967Proxy(address(debtTokenImpl), data)));
        vm.stopPrank();
    }

    function _deployCommunityIssuance(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(communityIssuance) == address(0)); // check if contract is not deployed
        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (OWNER, oshiToken, address(satoshiXApp)));
        communityIssuance = ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
        vm.stopPrank();
    }

    function _deploySortedTrovesBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(sortedTrovesBeacon) == address(0)); // check if contract is not deployed
        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl), OWNER);
        vm.stopPrank();
    }

    function _deployTroveManagerBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(troveManagerBeacon) == address(0)); // check if contract is not deployed
        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl), OWNER);
        vm.stopPrank();
    }

    function _deployOSHIToken(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(oshiToken) == address(0)); // check if contract is not deployed
        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, OWNER);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));
        vm.stopPrank();
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

        vm.startPrank(deployer);
        diamond.diamondCut(facetCuts, address(0), "");
        vm.stopPrank();
    }

    function _satoshiXAppInit(address deployer) internal {
        assert(address(satoshiXApp) != address(0));
        assert(address(initializer) != address(0));

        vm.startPrank(deployer);
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
        vm.stopPrank();
    }

    function _deployWETH(address deployer) internal {
        vm.startPrank(deployer);
        weth = IWETH(address(new WETH9()));
        vm.stopPrank();
    }

    function assertContractAddressHasCode(address contractAddress) public {
        // Check if the contract address has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(contractAddress)
        }

        // Assert that the code size is greater than 0
        assertTrue(codeSize > 0, "The address does not contain a contract.");
    }
}
