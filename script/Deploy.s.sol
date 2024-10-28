// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISatoshiXApp} from "../src/core/interfaces/ISatoshiXApp.sol";
import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {Initializer} from "../src/core/Initializer.sol";

import {Builder} from "./utils/Builder.sol";
import {Deployer} from "./utils/Deployer.sol";

import {Script, console} from "forge-std/Script.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IERC2535DiamondCutInternal} from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";

import {ICoreFacet} from "../src/core/interfaces/ICoreFacet.sol";
import {IRewardManager} from "../src/OSHI/interfaces/IRewardManager.sol";
import {ICommunityIssuance} from "../src/OSHI/interfaces/ICommunityIssuance.sol";
import {IOSHIToken} from "../src/OSHI/interfaces/IOSHIToken.sol";
import {IDebtToken} from "../src/core/interfaces/IDebtToken.sol";

contract DeployScript is Script, IERC2535DiamondCutInternal {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public deployer;
    address public satoshiCoreOwner;

    uint256 public constant TOTAL_FACETS = 7;

    // TODO
    address public constant LZ_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // XApp
    address payable satoshiXApp;

    // Facets
    address coreFacet;
    address borrowerOperationsFacet;
    address factoryFacet;
    address liquidationFacet;
    address nexusYieldManagerFacet;
    address priceFeedAggregatorFacet;
    address stabilityPoolFacet;

    // Initializer
    address initializer;

    // Core contracts
    IBeacon sortedTrovesBeacon;
    IBeacon troveManagerBeacon;
    IDebtToken debtToken;

    // OSHI contracts
    IRewardManager rewardManager;
    IOSHIToken oshiToken;
    ICommunityIssuance communityIssuance;

    function setUp() external {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);

        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        assert(OWNER_PRIVATE_KEY != 0);
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);
    }

    function run() public {
        _deployContracts();

        _updateFacetCuts();
        _initSatoshiXApp();
    }

    function _deployContracts() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        satoshiXApp = Deployer._deploySatoshiXApp();

        (
            coreFacet,
            borrowerOperationsFacet,
            factoryFacet,
            liquidationFacet,
            nexusYieldManagerFacet,
            priceFeedAggregatorFacet,
            stabilityPoolFacet
        ) = Deployer._deployFacets();

        initializer = Deployer._deployInitializer();
        (sortedTrovesBeacon, troveManagerBeacon) = Deployer._deployTrovesBeacons(satoshiCoreOwner);
        (oshiToken, communityIssuance, rewardManager) = Deployer._deployOSHIToken(satoshiXApp, satoshiCoreOwner);
        debtToken = Deployer._deployDebtToken(satoshiXApp, LZ_ENDPOINT, satoshiCoreOwner);

        console.log("======= SATOSHI X APP =======");
        console.log("SatoshiXApp: ", satoshiXApp);
        console.log("Initializer: ", initializer);

        console.log("======= FACETS =======");
        console.log("CoreFacet: ", coreFacet);
        console.log("BorrowerOperationsFacet: ", borrowerOperationsFacet);
        console.log("FactoryFacet: ", factoryFacet);
        console.log("LiquidationFacet: ", liquidationFacet);
        console.log("NexusYieldManagerFacet: ", nexusYieldManagerFacet);
        console.log("PriceFeedAggregatorFacet: ", priceFeedAggregatorFacet);
        console.log("StabilityPoolFacet: ", stabilityPoolFacet);

        console.log("======= CORE CONTRACTS =======");
        console.log("SortedTrovesBeacon: ", address(sortedTrovesBeacon));
        console.log("TroveManagerBeacon: ", address(troveManagerBeacon));
        console.log("DebtToken: ", address(debtToken));

        console.log("======= OSHI TOKEN =======");
        console.log("RewardManager: ", address(rewardManager));
        console.log("OSHIToken: ", address(oshiToken));
        console.log("CommunityIssuance: ", address(communityIssuance));

        console.log("\n");
        vm.stopBroadcast();
    }

    function _updateFacetCuts() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        FacetCut[] memory facetCuts = new FacetCut[](TOTAL_FACETS);

        facetCuts[0] = Builder.buildCoreFacet(coreFacet);
        facetCuts[1] = Builder.buildBorrowerOperationsFacet(borrowerOperationsFacet);
        facetCuts[2] = Builder.buildFactoryFacet(factoryFacet);
        facetCuts[3] = Builder.buildLiquidationFacet(liquidationFacet);
        facetCuts[4] = Builder.buildNexusYieldManagerFacet(nexusYieldManagerFacet);
        facetCuts[5] = Builder.buildPriceFeedAggregatorFacet(priceFeedAggregatorFacet);
        facetCuts[6] = Builder.buildStabilityPoolFacet(stabilityPoolFacet);

        ISatoshiXApp(satoshiXApp).diamondCut(facetCuts, address(0), "");
        console.log("Updated facet cuts");

        vm.stopBroadcast();
    }

    function _initSatoshiXApp() internal {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        FacetCut[] memory facetCuts = new FacetCut[](1);
        facetCuts[0] = Builder.buildInitializer(initializer);

        bytes memory _data = abi.encode(
            address(rewardManager),
            address(debtToken),
            address(communityIssuance),
            address(sortedTrovesBeacon),
            address(troveManagerBeacon)
        );
        bytes memory data = abi.encodeWithSelector(Initializer.init.selector, _data);

        ISatoshiXApp(satoshiXApp).diamondCut(facetCuts, initializer, data);
        console.log("Initialized SatoshiXApp");

        vm.stopBroadcast();
    }
}
