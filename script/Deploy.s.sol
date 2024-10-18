// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISatoshiXApp} from "../src/core/interfaces/ISatoshiXApp.sol";
import {SatoshiXApp} from "../src/core/SatoshiXApp.sol";
import {Initializer} from "../src/core/Initializer.sol";

import {Builder} from "./utils/Builder.sol";
import {DeployBase} from "./utils/DeployBase.sol";

import {Script, console} from "forge-std/Script.sol";
import {IERC2535DiamondCutInternal} from "@solidstate/contracts/interfaces/IERC2535DiamondCutInternal.sol";

contract DeployScript is DeployBase, IERC2535DiamondCutInternal {
    uint256 public constant TOTAL_FACETS = 7;

    address public deployer;

    function run() public {
        vm.startBroadcast();

        _deployContracts();

        _initSatoshiXApp();
        _updateFacetCuts();

        vm.stopBroadcast();
    }

    function _deployContracts() internal {
        _deploySatoshiXApp();
        _deployFacets();
        _deployInitializer();

        _deployOSHIToken();

        _deployDebtToken();
        _deploySortedTrovesBeacon();
        _deployTroveManagerBeacon();

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

        console.log("======= OSHI TOKEN =======");
        console.log("RewardManager: ", address(rewardManager));
        console.log("OSHIToken: ", address(oshiToken));
        console.log("CommunityIssuance: ", address(communityIssuance));

        console.log("======= CORE CONTRACTS =======");
        console.log("DebtToken: ", address(debtToken));
        console.log("SortedTrovesBeacon: ", address(sortedTrovesBeacon));
        console.log("TroveManagerBeacon: ", address(troveManagerBeacon));
    }

    function _updateFacetCuts() internal {
        FacetCut[] memory facetCuts = new FacetCut[](TOTAL_FACETS);

        facetCuts[0] = Builder.buildCoreFacet(coreFacet);
        facetCuts[1] = Builder.buildBorrowerOperationsFacet(borrowerOperationsFacet);
        facetCuts[2] = Builder.buildFactoryFacet(factoryFacet);
        facetCuts[3] = Builder.buildLiquidationFacet(liquidationFacet);
        facetCuts[4] = Builder.buildNexusYieldManagerFacet(nexusYieldManagerFacet);
        facetCuts[5] = Builder.buildPriceFeedAggregatorFacet(priceFeedAggregatorFacet);
        facetCuts[6] = Builder.buildStabilityPoolFacet(stabilityPoolFacet);

        ISatoshiXApp(satoshiXApp).diamondCut(facetCuts, address(0), "");
    }

    function _initSatoshiXApp() internal {
        FacetCut[] memory facetCuts = new FacetCut[](1);
        facetCuts[0] = Builder.buildInitializer(coreFacet);

        bytes memory data = abi.encodeWithSelector(
            Initializer.init.selector,
            address(rewardManager),
            address(debtToken),
            address(communityIssuance),
            address(sortedTrovesBeacon),
            address(troveManagerBeacon)
        );

        ISatoshiXApp(satoshiXApp).diamondCut(facetCuts, initializer, data);
    }
}
