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
import {Initializer} from "../../src/core/Initializer.sol";

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

abstract contract DeployBase is Test {
    ISatoshiXApp internal satoshiXApp;
    IBorrowerOperationsFacet internal borrowerOperationsFacet;
    ICoreFacet internal coreFacet;
    IFactoryFacet internal factoryFacet;
    ILiquidationFacet internal liquidationFacet;
    IPriceFeedAggregatorFacet internal priceFeedAggregatorFacet;
    IStabilityPoolFacet internal stabilityPoolFacet;
    Initializer internal initializer;

    IDebtToken internal debtToken;
    IRewardManager internal rewardManager;
    ICommunityIssuance internal communityIssuance;
    IOSHIToken internal oshiToken;

    IBeacon internal sortedTrovesBeacon;
    IBeacon internal troveManagerBeacon;

    function setUp() public virtual {
        _deployOSHIToken(DEPLOYER);
        _deployDebtToken(DEPLOYER);
        _deployRewardManager(DEPLOYER);
        _deployCommunityIssuance(DEPLOYER);
        _deploySortedTrovesBeacon(DEPLOYER);
        _deployTroveManagerBeacon(DEPLOYER);
        _deploySatoshiXApp(DEPLOYER);
        _deployAndCutFacets(DEPLOYER);
        _deployInitializer(DEPLOYER);
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
        bytes4[] memory selectors = new bytes4[](10);
        //TODO add selectors
        vm.stopPrank();
        return (address(coreFacet), selectors);
    }

    function _deployFactoryFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(factoryFacet) == address(0)); // check if contract is not deployed
        factoryFacet = IFactoryFacet(address(new FactoryFacet()));
        bytes4[] memory selectors = new bytes4[](10);
        //TODO add selectors
        vm.stopPrank();
        return (address(factoryFacet), selectors);
    }

    function _deployLiquidationFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(liquidationFacet) == address(0)); // check if contract is not deployed
        liquidationFacet = ILiquidationFacet(address(new LiquidationFacet()));
        bytes4[] memory selectors = new bytes4[](10);
        //TODO add selectors
        vm.stopPrank();
        return (address(liquidationFacet), selectors);
    }

    function _deployPriceFeedAggregatorFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(priceFeedAggregatorFacet) == address(0)); // check if contract is not deployed
        priceFeedAggregatorFacet = IPriceFeedAggregatorFacet(address(new PriceFeedAggregatorFacet()));
        bytes4[] memory selectors = new bytes4[](10);
        //TODO add selectors
        vm.stopPrank();
        return (address(priceFeedAggregatorFacet), selectors);
    }

    function _deployStabilityPoolFacet(address deployer) internal returns (address, bytes4[] memory) {
        vm.startPrank(deployer);
        assert(address(stabilityPoolFacet) == address(0)); // check if contract is not deployed
        stabilityPoolFacet = IStabilityPoolFacet(address(new StabilityPoolFacet()));
        bytes4[] memory selectors = new bytes4[](10);
        //TODO add selectors
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
    }

    function _deployDebtToken(address deployer) internal {
        vm.startPrank(deployer);
        assert(address(debtToken) == address(0)); // check if contract is not deployed
        address debtTokenImpl = address(new DebtToken());
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
        bytes memory data = abi.encodeWithSelector(
            Initializer.init.selector,
            address(rewardManager),
            address(debtToken),
            address(communityIssuance),
            address(sortedTrovesBeacon),
            address(troveManagerBeacon)
        );
        satoshiXApp.diamondCut(facetCuts, address(initializer), data);
        vm.stopPrank();
    }
}
