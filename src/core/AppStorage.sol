
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "./interfaces/ITroveManager.sol";
import {TroveManagerData} from "./interfaces/IBorrowerOperationsFacet.sol";
import {IDebtToken} from "./interfaces/IDebtToken.sol";
import {Queue, SunsetIndex, AccountDeposit, Snapshots} from "./interfaces/IStabilityPoolFacet.sol";
import {OracleRecord} from "./interfaces/IPriceFeedAggregatorFacet.sol";
import {ICommunityIssuance} from "./../OSHI/interfaces/ICommunityIssuance.sol";
import {IRewardManager} from "./../OSHI/interfaces/IRewardManager.sol";
import {IXAppRouter} from "./interfaces/IXAppRouter.sol";
import {AssetConfig, ChainConfig} from "./interfaces/INexusYieldManagerFacet.sol";

library AppStorage {
    bytes32 internal constant STORAGE_SLOT = bytes32(uint256(keccak256("satoshi.app.storage")) - 1);

    struct Layout {
        IXAppRouter xAppRouter;
        address feeReceiver;
        address gasPool;
        IRewardManager rewardManager;
        ICommunityIssuance communityIssuance;
        address pendingOwner;
        uint256 ownershipTransferDeadline;
        bool paused;
        uint256 startTime;
        IDebtToken debtToken;
        uint256 minNetDebt;
        // owner => caller => isApproved
        mapping(address => mapping(address => bool)) isApprovedDelegate;
        /* Factory */
        IBeacon sortedTrovesBeacon;
        IBeacon troveManagerBeacon;
        // troveManager => enabled
        mapping(ITroveManager => bool) enabledTroveManagers;
        /* Liquidation */
        mapping(ITroveManager => TroveManagerData) troveManagersData;
        ITroveManager[] troveManagers;
        /* Stability Pool */
        // OSHI reward
        uint128 spRewardRate;
        uint32 lastUpdate;
        uint32 claimStartTime;
        // collateral => index
        mapping(IERC20 => uint256) indexByCollateral;
        IERC20[] collateralTokens;
        /* collateral Gain sum 'S': During its lifetime, each deposit d_t earns a collateral gain of ( d_t * [S - S_t] )/P_t, where S_t
        * is the depositor's snapshot of S taken at the time t when the deposit was made.
        *
        * The 'S' sums are stored in a nested mapping (epoch => scale => sum):
        *
        * - The inner mapping records the sum S at different scales
        * - The outer mapping records the (scale => sum) mappings, for different epochs.
        */

        // index values are mapped against the values within `collateralTokens`
        mapping(uint128 => mapping(uint128 => uint256[256])) epochToScaleToSums;
        // Each time the scale of P shifts by SCALE_FACTOR, the scale is incremented by 1
        uint128 currentScale;
        // With each offset that fully empties the Pool, the epoch is incremented by 1
        uint128 currentEpoch;
        Queue queue;
        mapping(uint16 => SunsetIndex) sunsetIndexes;
        // Tracker for Debt held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
        uint256 totalDebtTokenDeposits;
        /*  Product 'P': Running product by which to multiply an initial deposit, in order to find the current compounded deposit,
        * after a series of liquidations have occurred, each of which cancel some debt with the deposit.
        *
        * During its lifetime, a deposit's value evolves from d_t to d_t * P / P_t , where P_t
        * is the snapshot of P taken at the instant the deposit was made. 18-digit decimal.
        */
        uint256 P; // init to DECIMAL_PRECISION
        // Error trackers for the error correction in the OSHI offset calculation
        uint256[256] lastCollateralError_Offset;
        uint256 lastDebtLossError_Offset;
        // Error tracker for the error correction in the OSHI issuance calculation
        uint256 lastOSHIError;
        /*
        * Similarly, the sum 'G' is used to calculate OSHI gains. During it's lifetime, each deposit d_t earns a OSHI gain of
        *  ( d_t * [G - G_t] )/P_t, where G_t is the depositor's snapshot of G taken at time t when the deposit was made.
        *
        *  OSHI reward events occur are triggered by depositor operations (new deposit, topup, withdrawal), and liquidations.
        *  In each case, the OSHI reward is issued (i.e. G is updated), before other state changes are made.
        */
        mapping(uint128 => mapping(uint128 => uint256)) epochToScaleToG;
        mapping(address => AccountDeposit) accountDeposits; // depositor address -> initial deposit
        mapping(address => Snapshots) depositSnapshots; // depositor address -> snapshots struct
        // index values are mapped against the values within `collateralTokens`
        mapping(address => uint256[256]) depositSums; // depositor address -> sums
        // depositor => gains
        mapping(address => uint80[256]) collateralGainsByDepositor;
        mapping(address => uint256) storedPendingReward;
        /* PriceFeedAggregatorFacet */
        mapping(IERC20 => OracleRecord) oracleRecords;
        /* Nexus Yield Manager */
        bool isNymPaused;
        uint256 day;
        mapping(address => bool) isPrivileged;
        mapping(address => mapping(address => uint32)) withdrawalTime;
        mapping(address => mapping(address => uint256)) scheduledWithdrawalAmount;
        mapping(address => AssetConfig) assetConfigs;
        mapping(address => bool) isAssetSupported;
        mapping(address => uint256) dailyMintCount;
    }

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            s.slot := slot
        }
    }
}
