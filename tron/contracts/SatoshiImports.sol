// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Core contracts in DeploySetup.s.sol deployment flow.
import { SatoshiXApp } from "../../src/core/SatoshiXApp.sol";
import { Initializer as SatoshiInitializer } from "../../src/core/Initializer.sol";
import { GasPool } from "../../src/core/GasPool.sol";
import { DebtToken } from "../../src/core/DebtToken.sol";
import { DebtTokenWithLz } from "../../src/core/DebtTokenWithLz.sol";
import { SortedTroves } from "../../src/core/SortedTroves.sol";
import { TroveManager } from "../../src/core/TroveManager.sol";

// Diamond facets.
import { BorrowerOperationsFacet } from "../../src/core/facets/BorrowerOperationsFacet.sol";
import { CoreFacet } from "../../src/core/facets/CoreFacet.sol";
import { FactoryFacet } from "../../src/core/facets/FactoryFacet.sol";
import { LiquidationFacet } from "../../src/core/facets/LiquidationFacet.sol";
import { NexusYieldManagerFacet } from "../../src/core/facets/NexusYieldManagerFacet.sol";
import { PriceFeedAggregatorFacet } from "../../src/core/facets/PriceFeedAggregatorFacet.sol";
import { StabilityPoolFacet } from "../../src/core/facets/StabilityPoolFacet.sol";

// OSHI + managers.
import { OSHIToken } from "../../src/OSHI/OSHIToken.sol";
import { CommunityIssuance } from "../../src/OSHI/CommunityIssuance.sol";
import { RewardManager } from "../../src/OSHI/RewardManager.sol";
import { VaultManager } from "../../src/vault/VaultManager.sol";

// OpenZeppelin proxy contracts used by migrations.
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

// Helper contracts.
import { SatoshiPeriphery } from "../../src/core/helpers/SatoshiPeriphery.sol";
import { SwapRouter } from "../../src/core/helpers/SwapRouter.sol";
import { MultiCollateralHintHelpers } from "../../src/core/helpers/MultiCollateralHintHelpers.sol";
import { MultiTroveGetter } from "../../src/core/helpers/MultiTroveGetter.sol";
import { TroveHelper } from "../../src/core/helpers/TroveHelper.sol";
import { TroveManagerGetter } from "../../src/core/helpers/TroveManagerGetter.sol";

// Price feed contracts.
import { PriceFeedChainlink } from "../../src/priceFeed/PriceFeedChainlink.sol";

// Test mocks usable for local Tron deployment flows.
import { OracleMock } from "../../test/mocks/OracleMock.sol";
import { ERC20Mock } from "../../test/mocks/ERC20Mock.sol";
