// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ICommunityIssuance } from "../OSHI/interfaces/ICommunityIssuance.sol";
import { IRewardManager } from "../OSHI/interfaces/IRewardManager.sol";
import { Utils } from "../library/Utils.sol";
import { AppStorage } from "./AppStorage.sol";
import { Config } from "./Config.sol";
import { IDebtToken } from "./interfaces/IDebtToken.sol";
import { IBeacon } from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import { AccessControlInternal } from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import { OwnableInternal } from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import { Initializable } from "@solidstate/contracts/security/initializable/Initializable.sol";

import { ICommunityIssuance } from "../OSHI/interfaces/ICommunityIssuance.sol";
import { IRewardManager } from "../OSHI/interfaces/IRewardManager.sol";

contract Initializer is Initializable, AccessControlInternal, OwnableInternal {
    using Utils for *;

    /**
     * @notice Initialize function for the SatoshiXAPP contract
     * @dev This function is called only once when the protocol is deployed
     * @param data The encoded data for the initializer
     */
    function init(bytes calldata data) external initializer {
        (
            address rewardManager,
            address debtToken,
            address communityIssuance,
            address sortedTrovesBeacon,
            address troveManagerBeacon,
            address gasPool,
            address owner,
            address guardian,
            address feeReceiver,
            uint256 minNetDebt,
            uint256 gasCompensation
        ) = abi.decode(
            data, (address, address, address, address, address, address, address, address, address, uint256, uint256)
        );

        rewardManager.ensureNonzeroAddress();
        debtToken.ensureNonzeroAddress();
        communityIssuance.ensureNonzeroAddress();
        sortedTrovesBeacon.ensureNonzeroAddress();
        troveManagerBeacon.ensureNonzeroAddress();
        gasPool.ensureNonzeroAddress();
        owner.ensureNonzeroAddress();
        guardian.ensureNonzeroAddress();
        feeReceiver.ensureNonzeroAddress();
        minNetDebt.ensureNonZero();
        gasCompensation.ensureNonZero();

        // set roles
        _setRoleAdmin(Config.OWNER_ROLE, Config.OWNER_ROLE);
        _setRoleAdmin(Config.GUARDIAN_ROLE, Config.OWNER_ROLE);
        _grantRole(Config.OWNER_ROLE, owner);
        _grantRole(Config.GUARDIAN_ROLE, guardian);

        AppStorage.Layout storage s = AppStorage.layout();
        s.feeReceiver = feeReceiver;
        s.rewardManager = IRewardManager(rewardManager);
        s.debtToken = IDebtToken(debtToken);
        s.communityIssuance = ICommunityIssuance(communityIssuance);
        s.startTime = block.timestamp;
        s.gasPool = gasPool;

        /**
         * BorrowerOperationsFacet
         */
        s.minNetDebt = minNetDebt;

        /**
         * CoreFacet
         */
        s.gasCompensation = gasCompensation;
        // feeReceiver
        // rewardManager
        // startTime
        // guardian

        /**
         * FactoryFacet
         */
        s.sortedTrovesBeacon = IBeacon(sortedTrovesBeacon);
        s.troveManagerBeacon = IBeacon(troveManagerBeacon);

        /**
         * LiquidationFacet
         */
        // None

        /**
         * PriceFeedAggregatorFacet
         */
        // None

        /**
         * StabilityPoolFacet
         */
        // communityIssuance
        s.P = Config.DEBT_TOKEN_DECIMALS_BASE;
        s.lastUpdate = uint32(block.timestamp);

        /**
         * NexusYieldManagerFacet
         */
        // debtToken
        // rewardManager
    }
}
