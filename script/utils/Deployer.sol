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

library Deployer {
    //! COPY FROM TEST
    address constant DEPLOYER = 0x1234567890123456789012345678901234567890;
    address constant OWNER = 0x1111111111111111111111111111111111111111;
    address constant LZ_ENDPOINT = 0x1234567890123456789012345678901234567890;
    address constant GUARDIAN = 0x2222222222222222222222222222222222222222;
    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "SAT";

    function isDeployed(address _addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        require(size > 0, "Contract not deployed");
    }

    function _deploySatoshiXApp() internal returns (address payable) {
        return payable(address(new SatoshiXApp()));
    }

    function _deployFacets()
        internal
        returns (
            address coreFacet,
            address borrowerOperationsFacet,
            address factoryFacet,
            address liquidationFacet,
            address nexusYieldManagerFacet,
            address priceFeedAggregatorFacet,
            address stabilityPoolFacet
        )
    {
        coreFacet = address(new CoreFacet());
        borrowerOperationsFacet = address(new BorrowerOperationsFacet());
        factoryFacet = address(new FactoryFacet());
        liquidationFacet = address(new LiquidationFacet());
        nexusYieldManagerFacet = address(new NexusYieldManagerFacet());
        priceFeedAggregatorFacet = address(new PriceFeedAggregatorFacet());
        stabilityPoolFacet = address(new PriceFeedAggregatorFacet());
    }

    function _deployInitializer() internal returns (address) {
        return address(new Initializer());
    }

    // function _deployDebtToken(address satoshiXApp) internal returns (IDebtToken) {
    //     assert(address(debtToken) == address(0)); // check if contract is not deployed
    //     assert(address(satoshiXApp) != address(0)); // check if contract is not deployed

    //     address debtTokenImpl = address(new DebtToken(LZ_ENDPOINT));
    //     bytes memory data =
    //         abi.encodeCall(IDebtToken.initialize, (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, address(satoshiXApp), OWNER));

    //     debtToken = IDebtToken(address(new ERC1967Proxy(debtTokenImpl, data)));
    // }

    function _deployTrovesBeacons() internal returns (IBeacon sortedTrovesBeacon, IBeacon troveManagerBeacon) {
        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(sortedTrovesImpl, OWNER);

        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(troveManagerImpl, OWNER);
    }

    function _deployOSHIToken(address _satoshiXApp)
        internal
        returns (IOSHIToken oshiToken, ICommunityIssuance communityIssuance, IRewardManager rewardManager)
    {
        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, OWNER);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));

        communityIssuance = _deployCommunityIssuance(oshiToken, _satoshiXApp);
        rewardManager = _deployRewardManager();
    }

    function _deployHelpers(address satoshiXApp)
        internal
        returns (
            address multiCollateralHintHelpers,
            address troveHelper,
            address multiTroveGetter,
            address troveManagerGetters
        )
    {
        multiCollateralHintHelpers = address(new MultiCollateralHintHelpers(satoshiXApp));
        multiTroveGetter = address(new MultiTroveGetter());
        troveHelper = address(new TroveHelper());
        troveManagerGetters = address(new TroveManagerGetters(satoshiXApp));
    }

    function _deployCommunityIssuance(IOSHIToken oshiToken, address satoshiXApp) private returns (ICommunityIssuance) {
        assert(address(oshiToken) != address(0)); // check if OSHI token is deployed

        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (OWNER, oshiToken, address(satoshiXApp)));
        return ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
    }

    function _deployRewardManager() private returns (IRewardManager) {
        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(RewardManager.initialize, (InitialConfig.OWNER));
        return IRewardManager(address(new ERC1967Proxy(rewardManagerImpl, data)));
    }
}
