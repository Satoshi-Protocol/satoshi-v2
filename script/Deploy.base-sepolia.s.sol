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
import {MultiTroveGetter} from "../src/core/helpers/MultiTroveGetter.sol";
import {IMultiTroveGetter} from "../src/core/helpers/interfaces/IMultiTroveGetter.sol";

import {IOSHIToken} from "../src/OSHI/interfaces/IOSHIToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {ISatoshiPeriphery} from "../src/core/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/core/helpers/SatoshiPeriphery.sol";
import {IWETH} from "../src/core/helpers/interfaces/IWETH.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {IGasPool} from "../src/core/interfaces/IGasPool.sol";
import {Config} from "../src/core/Config.sol";
import {Deployer} from "./Deployer.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {RoundData, OracleMock} from "../test/mocks/OracleMock.sol";

import "./configs/Config.testnet.sol";

contract DeployArbSepoliaScript is Deployer {
    string constant DEBT_TOKEN_NAME = "TEST_STABLECOIN_BASE";
    string constant DEBT_TOKEN_SYMBOL = "TESTSAT.base";
    address internal LZ_ENDPOINT = BASE_SEPOLIA_LZ_ENDPOINT;
    uint32 internal LZ_EID = BASE_SEPOLIA_LZ_EID;

    function setUp() external {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        assert(DEPLOYMENT_PRIVATE_KEY != 0);
        DEPLOYER = vm.addr(DEPLOYMENT_PRIVATE_KEY);

        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        assert(OWNER_PRIVATE_KEY != 0);
        OWNER = vm.addr(OWNER_PRIVATE_KEY);
        assert(LZ_ENDPOINT != address(0));
        assert(LZ_ENDPOINT != address(0));
    }

    function run() public {
        RoundData memory roundData = RoundData({
            answer: 9900000000000,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        OracleMock(0x6f4495b43B943FCBde43A610E1246042457FDE0B).updateRoundData(roundData);
        vm.stopBroadcast();

        return;

        console.log("deployer:", DEPLOYER);
        _deployWETH(DEPLOYER);
        _deploySortedTrovesBeacon(DEPLOYER);
        _deployTroveManagerBeacon(DEPLOYER);
        _deployInitializer(DEPLOYER);
        _deploySatoshiXApp(DEPLOYER);
        _deployAndCutFacets(DEPLOYER);
        _deployOSHIToken(DEPLOYER);
        _deployGasPool(DEPLOYER);
        _deployDebtToken(LZ_EID, LZ_ENDPOINT, DEPLOYER, DEBT_TOKEN_NAME, DEBT_TOKEN_SYMBOL);
        _deployCommunityIssuance(DEPLOYER);
        _deployRewardManager(DEPLOYER);
        _deployPeriphery(DEPLOYER);
        _satoshiXAppInit(DEPLOYER);
        _setContracts(DEPLOYER);

        consoleAllContract();

        (
            IERC20 collateralMock,
            ISortedTroves sortedTrovesBeaconProxy,
            ITroveManager troveManagerBeaconProxy,
            IMultiCollateralHintHelpers hintHelpers,
            IMultiTroveGetter multiTroveGetter,
            address oracleMock
        ) = deployMockCollateral(DEPLOYER);
        console.log("collateralMock:", address(collateralMock));
        console.log("sortedTrovesBeaconProxy:", address(sortedTrovesBeaconProxy));
        console.log("troveManagerBeaconProxy:", address(troveManagerBeaconProxy));
        console.log("hintHelpers:", address(hintHelpers));
        console.log("multiTroveGetter:", address(multiTroveGetter));
        console.log("oracleMock:", address(oracleMock));

        // NOTE: For Test
        ERC20Mock coll = ERC20Mock(address(collateralMock));
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        coll.mint(DEPLOYER, 1000 * (10 ** coll.decimals()));
        debtToken.rely(DEPLOYER);
        debtToken.mint(DEPLOYER, 10000e18);
        coll.mint(0x317d2da746d1360F4c113E7962a33394DB2A1A4e, 1000 * (10 ** coll.decimals()));
        debtToken.rely(0x317d2da746d1360F4c113E7962a33394DB2A1A4e);
        debtToken.mint(0x317d2da746d1360F4c113E7962a33394DB2A1A4e, 10000e18);
        vm.stopBroadcast();
    }
}
