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

contract DeployScript is Script, IERC2535DiamondCutInternal {
    uint256 public constant MOCK_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public constant TOTAL_FACETS = 7;

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

    // OSHI contracts
    IRewardManager rewardManager;
    IOSHIToken oshiToken;
    ICommunityIssuance communityIssuance;

    function run() public {
        _deployContracts();

        _updateFacetCuts();
        _initSatoshiXApp();
    }

    function _deployContracts() internal {
        vm.startBroadcast(MOCK_PK);

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
        (sortedTrovesBeacon, troveManagerBeacon) = Deployer._deployTrovesBeacons();
        (oshiToken, communityIssuance, rewardManager) = Deployer._deployOSHIToken(satoshiXApp);

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

        console.log("======= OSHI TOKEN =======");
        console.log("RewardManager: ", address(rewardManager));
        console.log("OSHIToken: ", address(oshiToken));
        console.log("CommunityIssuance: ", address(communityIssuance));

        console.log("\n");
        vm.stopBroadcast();
    }

    function _updateFacetCuts() internal {
        vm.startBroadcast(MOCK_PK);

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
        vm.startBroadcast(MOCK_PK);

        FacetCut[] memory facetCuts = new FacetCut[](1);
        facetCuts[0] = Builder.buildInitializer(initializer);

        bytes memory _data = abi.encode(address(123), address(3452), address(563), address(346), address(23));
        bytes memory data = abi.encodeWithSelector(Initializer.init.selector, _data);

        ISatoshiXApp(satoshiXApp).diamondCut(facetCuts, initializer, data);
        console.log("Initialized SatoshiXApp");

        vm.stopBroadcast();
    }
}
