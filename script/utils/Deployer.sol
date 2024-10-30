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
import {Config} from "./Config.sol";
import {Builder} from "./Builder.sol";
import {SatoshiPeriphery} from "../../src/core/helpers/SatoshiPeriphery.sol";

import {IRewardManager} from "../../src/OSHI/interfaces/IRewardManager.sol";
import {ICommunityIssuance} from "../../src/OSHI/interfaces/ICommunityIssuance.sol";
import {IOSHIToken} from "../../src/OSHI/interfaces/IOSHIToken.sol";
import {IDebtToken} from "../../src/core/interfaces/IDebtToken.sol";
import {ISortedTroves} from "../../src/core/interfaces/ISortedTroves.sol";
import {ITroveManager} from "../../src/core/interfaces/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../../src/core/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IMultiTroveGetter} from "../../src/core/helpers/interfaces/IMultiTroveGetter.sol";
import {ITroveHelper} from "../../src/core/helpers/interfaces/ITroveHelper.sol";
import {IBorrowerOperationsFacet} from "../../src/core/interfaces/IBorrowerOperationsFacet.sol";
import {IWETH} from "../../src/core/helpers/interfaces/IWETH.sol";
import {ISatoshiPeriphery} from "../../src/core/helpers/interfaces/ISatoshiPeriphery.sol";

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
    using Builder for uint32;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Get contract address from the latest-run data in broadcast
    /// @dev Detect chain ID to get correct the broadcast folder path
    /// @param deployFile The deploy file name in broadcast path
    /// @param contractName The contract name for searching
    /// @return The contract address
    function getContractAddress(string memory deployFile, string memory contractName) public view returns (address) {
        string memory latestRunPath =
            string.concat("broadcast/", deployFile, ".s.sol/", vm.toString(block.chainid), "/run-latest.json");

        string memory latestRun = vm.readFile(latestRunPath);
        string[] memory txs = latestRun.readStringArray(".transactions");

        for (uint32 i = 0; i < txs.length; i++) {
            string memory _contractName = latestRun.readString(i.buildTxsFilePath("contractName"));

            if (_contractName.equal(contractName)) {
                return latestRun.readAddress(i.buildTxsFilePath("contractAddress"));
            }
        }

        revert("Contract not found");
    }

    /// @notice Get the address of the ERC1967Proxy contract by implementation address
    /// @dev Get address by first impl address in CREATE arguments
    /// @param deployFile The deploy file name in broadcast path
    /// @param impl The implementation address in Proxy contract
    /// @return The ERC1967Proxy contract address
    function getERC1967ProxyAddress(string memory deployFile, address impl) public view returns (address) {
        string memory latestRunPath =
            string.concat("broadcast/", deployFile, ".s.sol/", vm.toString(block.chainid), "/run-latest.json");

        string memory latestRun = vm.readFile(latestRunPath);
        string[] memory txs = latestRun.readStringArray(".transactions");

        for (uint32 i = 0; i < txs.length; i++) {
            string memory _contractName = latestRun.readString(i.buildTxsFilePath("contractName"));
            string memory _txType = latestRun.readString(i.buildTxsFilePath("transactionType"));

            if (_contractName.equal("ERC1967Proxy") && (_txType.equal("CREATE"))) {
                address _impl = latestRun.readAddress(i.buildTxsFilePath("arguments[0]"));

                if (_impl == impl) {
                    return latestRun.readAddress(i.buildTxsFilePath("contractAddress"));
                }
            }
        }

        revert("Contract not found");
    }

    /// @notice Check if the contract is deployed and the deployed code matches the expected code
    /// @param _addr The contract address
    /// @param contractName The contract name in project for searching deployed code. e.g. SatoshiXApp.sol:SatoshiXApp
    function _verifyContractDeployed(address _addr, string memory contractName) internal view {
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

    function _deployDebtToken(address satoshiXApp, address lzEndpoing, address owner)
        internal
        returns (IDebtToken debtToken)
    {
        _verifyContractDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");
        require(lzEndpoing != address(0), "LZ endpoint address is zero address");

        address debtTokenImpl = address(new DebtToken(lzEndpoing));
        bytes memory data = abi.encodeCall(
            IDebtToken.initialize, (Config.DEBT_TOKEN_NAME, Config.DEBT_TOKEN_SYMBOL, satoshiXApp, owner)
        );

        debtToken = IDebtToken(address(new ERC1967Proxy(debtTokenImpl, data)));
    }

    function _deployTrovesBeacons(address owner)
        internal
        returns (IBeacon sortedTrovesBeacon, IBeacon troveManagerBeacon)
    {
        address sortedTrovesImpl = address(new SortedTroves());
        sortedTrovesBeacon = new UpgradeableBeacon(sortedTrovesImpl, owner);

        address troveManagerImpl = address(new TroveManager());
        troveManagerBeacon = new UpgradeableBeacon(troveManagerImpl, owner);
    }

    function _deployOSHIToken(address _satoshiXApp, address owner)
        internal
        returns (IOSHIToken oshiToken, ICommunityIssuance communityIssuance, IRewardManager rewardManager)
    {
        _verifyContractDeployed(_satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

        address oshiTokenImpl = address(new OSHIToken());
        bytes memory data = abi.encodeCall(IOSHIToken.initialize, owner);
        oshiToken = IOSHIToken(address(new ERC1967Proxy(oshiTokenImpl, data)));

        communityIssuance = _deployCommunityIssuance(oshiToken, _satoshiXApp, owner);
        rewardManager = _deployRewardManager(owner);
    }

    function _deployPeriphery(address debtToken, address _weth, address satoshiXApp, address _owner)
        internal
        returns (address periphery)
    {
        _verifyContractDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");
        require(_weth != address(0), "WETH address is zero address");
        require(debtToken != address(0), "DebtToken address is zero address");
        require(_owner != address(0), "Owner address is zero address");

        bytes memory data =
            abi.encodeCall(ISatoshiPeriphery.initialize, (DebtToken(debtToken), IWETH(_weth), satoshiXApp, _owner));
        address peripheryImpl = address(new SatoshiPeriphery());

        periphery = address(new ERC1967Proxy(peripheryImpl, data));
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
        _verifyContractDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

        multiCollateralHintHelpers = address(new MultiCollateralHintHelpers(satoshiXApp));
        multiTroveGetter = address(new MultiTroveGetter());
        troveHelper = address(new TroveHelper());
        troveManagerGetters = address(new TroveManagerGetters(satoshiXApp));
    }

    function _deployCommunityIssuance(IOSHIToken oshiToken, address satoshiXApp, address owner)
        private
        returns (ICommunityIssuance)
    {
        _verifyContractDeployed(address(oshiToken), "ERC1967Proxy.sol:ERC1967Proxy");
        _verifyContractDeployed(satoshiXApp, "SatoshiXApp.sol:SatoshiXApp");

        address communityIssuanceImpl = address(new CommunityIssuance());
        bytes memory data = abi.encodeCall(ICommunityIssuance.initialize, (owner, oshiToken, address(satoshiXApp)));

        return ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
    }

    function _deployRewardManager(address owner) private returns (IRewardManager) {
        address rewardManagerImpl = address(new RewardManager());
        bytes memory data = abi.encodeCall(RewardManager.initialize, (owner));

        return IRewardManager(address(new ERC1967Proxy(rewardManagerImpl, data)));
    }
}
