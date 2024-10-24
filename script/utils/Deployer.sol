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

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

library Deployer {
    using stdJson for string;
    using Strings for string;

    //! COPY FROM TEST
    address constant DEPLOYER = 0x1234567890123456789012345678901234567890;
    address constant OWNER = 0x1111111111111111111111111111111111111111;
    address constant GUARDIAN = 0x2222222222222222222222222222222222222222;
    string constant DEBT_TOKEN_NAME = "SATOSHI_STABLECOIN";
    string constant DEBT_TOKEN_SYMBOL = "SAT";

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getSatoshiXApp() internal returns (address) {
        string memory latestRunPath =
            string.concat("broadcast/Deploy.s.sol/", vm.toString(block.chainid), "/run-latest.json");

        if (vm.exists(latestRunPath)) {
            string memory latestRun = vm.readFile(latestRunPath);
            string memory contractName = latestRun.readString("$.transactions[0].contractName");

            // dev: If deployment is first time, SatoshiXApp is deployed in the second transaction
            if (contractName.equal("Builder")) {
                return latestRun.readAddress("$.transactions[1].contractAddress");
            } else {
                return latestRun.readAddress("$.transactions[0].contractAddress");
            }
        } else {
            revert("SatoshiXApp not found");
        }
    }

    function _verifyDeployed(address _addr, string memory contractName) internal view {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        require(size > 0, "Contract not deployed");

        bytes memory code = _addr.code;
        bytes memory deployedCode = vm.getDeployedCode(contractName);

        require(keccak256(code) == keccak256(deployedCode), "Contract not matched");
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

    function _deployDebtToken(address satoshiXApp, address lzEndpoing) internal returns (IDebtToken debtToken) {
        _verifyDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

        address debtTokenImpl = address(new DebtToken(lzEndpoing));
        bytes memory data =
            abi.encodeCall(IDebtToken.initialize, (DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL, satoshiXApp, OWNER));

        debtToken = IDebtToken(address(new ERC1967Proxy(debtTokenImpl, data)));
    }

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
        _verifyDeployed(_satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

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
        _verifyDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

        multiCollateralHintHelpers = address(new MultiCollateralHintHelpers(satoshiXApp));
        multiTroveGetter = address(new MultiTroveGetter());
        troveHelper = address(new TroveHelper());
        troveManagerGetters = address(new TroveManagerGetters(satoshiXApp));
    }

    function _deployCommunityIssuance(IOSHIToken oshiToken, address satoshiXApp) private returns (ICommunityIssuance) {
        _verifyDeployed(address(oshiToken), "ERC1967Proxy.sol:ERC1967Proxy");
        _verifyDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

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
