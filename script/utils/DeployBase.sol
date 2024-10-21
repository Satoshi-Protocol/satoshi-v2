// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {CoreFacet} from "../../src/core/facets/CoreFacet.sol";
import {BorrowerOperationsFacet} from "../../src/core/facets/BorrowerOperationsFacet.sol";
import {FactoryFacet} from "../../src/core/facets/FactoryFacet.sol";
import {LiquidationFacet} from "../../src/core/facets/LiquidationFacet.sol";
import {NexusYieldManagerFacet} from "../../src/core/facets/NexusYieldManagerFacet.sol";
import {PriceFeedAggregatorFacet} from "../../src/core/facets/PriceFeedAggregatorFacet.sol";
import {StabilityPoolFacet} from "../../src/core/facets/StabilityPoolFacet.sol";
import {SatoshiXApp} from "../../src/core/SatoshiXApp.sol";
import {DebtToken} from "../../src/core/DebtToken.sol";
import {Initializer} from "../../src/core/Initializer.sol";
import {InitialConfig} from "../../src/core/InitialConfig.sol";
import {SortedTroves} from "../../src/core/SortedTroves.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {RewardManager} from "../../src/OSHI/RewardManager.sol";
import {CommunityIssuance} from "../../src/OSHI/CommunityIssuance.sol";
import {OSHIToken} from "../../src/OSHI/OSHIToken.sol";
import {MultiCollateralHintHelpers} from "../../src/core/helpers/MultiCollateralHintHelpers.sol";   
import {TroveHelper} from "../../src/core/helpers/TroveHelper.sol";
import {MultiTroveGetter} from "../../src/core/helpers/MultiTroveGetter.sol";
import {TroveManagerGetters} from "../../src/core/helpers/TroveManagerGetters.sol";

import {IRewardManager} from "../../src/OSHI/interfaces/IRewardManager.sol";
import {ICommunityIssuance} from "../../src/OSHI/interfaces/ICommunityIssuance.sol";
import {IOSHIToken} from "../../src/OSHI/interfaces/IOSHIToken.sol";
import {IDebtToken} from "../../src/core/interfaces/IDebtToken.sol";
import {ISortedTroves} from "../../src/core/interfaces/ISortedTroves.sol";
import {ITroveManager} from "../../src/core/interfaces/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";  
import {IMultiTroveGetter} from "../../src/core/helpers/interfaces/IMultiTroveGetter.sol";  
import {ITroveHelper} from "../../src/core/helpers/interfaces/ITroveHelper.sol";

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

abstract contract DeployBase is Script {
    //! COPY FROM TEST
    address constant DEPLOYER = 0x1234567890123456789012345678901234567890;
    address constant OWNER = 0x1111111111111111111111111111111111111111;
    address constant GUARDIAN = 0x2222222222222222222222222222222222222222;
    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "SAT";

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
    IDebtToken debtToken;
    IBeacon sortedTrovesBeacon;
    IBeacon troveManagerBeacon;

    // OSHI contracts
    IRewardManager rewardManager;
    IOSHIToken oshiToken;
    ICommunityIssuance communityIssuance;

    // Helpers
    IMultiCollateralHintHelpers multiCollateralHintHelpers;
    IMultiTroveGetter multiTroveGetter;
    ITroveHelper troveHelper;
    TroveManagerGetters troveManagerGetters;

    function _deploySatoshiXApp() internal {
        require(address(satoshiXApp) == address(0), "SatoshiXApp already deployed");

        satoshiXApp = payable(address(new SatoshiXApp()));
    }

    function _deployFacets() internal {
        require(address(coreFacet) == address(0), "coreFacet already deployed");
        require(address(borrowerOperationsFacet) == address(0), "borrowerOperationsFacet already deployed");
        require(address(factoryFacet) == address(0), "factoryFacet already deployed");
        require(address(liquidationFacet) == address(0), "liquidationFacet already deployed");
        require(address(nexusYieldManagerFacet) == address(0), "nexusYieldManagerFacet already deployed");
        require(address(priceFeedAggregatorFacet) == address(0), "priceFeedAggregatorFacet already deployed");
        require(address(stabilityPoolFacet) == address(0), "stabilityPoolFacet already deployed");

        coreFacet = address(new CoreFacet());
        borrowerOperationsFacet = address(new BorrowerOperationsFacet());
        factoryFacet = address(new FactoryFacet());
        liquidationFacet = address(new LiquidationFacet());
        nexusYieldManagerFacet = address(new NexusYieldManagerFacet());
        priceFeedAggregatorFacet = address(new PriceFeedAggregatorFacet());
        stabilityPoolFacet = address(new PriceFeedAggregatorFacet());
    }

    function _deployInitializer() internal {
        require(address(initializer) == address(0), "Initializer already deployed");

        initializer = address(new Initializer());
    }

    function _deployDebtToken() internal {
        assert(address(debtToken) == address(0)); // check if contract is not deployed
        assert(address(satoshiXApp) != address(0)); // check if contract is not deployed

        address debtTokenImpl = address(new DebtToken());
        bytes memory data =
            abi.encodeCall(IDebtToken.initialize, (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, address(satoshiXApp), OWNER));

        debtToken = IDebtToken(address(new ERC1967Proxy(debtTokenImpl, data)));
    }

    function _deploySortedTrovesBeacon() internal {
        assert(address(sortedTrovesBeacon) == address(0)); // check if contract is not deployed

        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(sortedTrovesImpl, OWNER);
    }

    function _deployTroveManagerBeacon() internal {
        assert(address(troveManagerBeacon) == address(0)); // check if contract is not deployed

        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(troveManagerImpl, OWNER);
    }

    function _deployOSHIToken() internal {
        assert(address(oshiToken) == address(0)); // check if contract is not deployed

        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, OWNER);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));

        _deployCommunityIssuance();
        _deployRewardManager();
    }

    function _deployHelpers() internal {
        multiCollateralHintHelpers = IMultiCollateralHintHelpers(address(new MultiCollateralHintHelpers(satoshiXApp)));    
        multiTroveGetter = IMultiTroveGetter(address(new MultiTroveGetter()));
        troveHelper = ITroveHelper(address(new TroveHelper()));
        troveManagerGetters = new TroveManagerGetters(satoshiXApp);
    }   

    function _deployCommunityIssuance() private {
        assert(address(communityIssuance) == address(0)); // check if contract is not deployed
        assert(address(oshiToken) != address(0)); // check if OSHI token is deployed

        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (OWNER, oshiToken, address(satoshiXApp)));
        communityIssuance = ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
    }

    function _deployRewardManager() private {
        assert(address(rewardManager) == address(0));

        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(RewardManager.initialize, (InitialConfig.OWNER));
        rewardManager = IRewardManager(address(new ERC1967Proxy(rewardManagerImpl, data)));
    }

    
}
