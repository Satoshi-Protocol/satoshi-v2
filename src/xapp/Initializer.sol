// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@solidstate/contracts/security/initializable/Initializable.sol";
import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {OwnableInternal} from "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {AppStorage} from "./storages/AppStorage.sol";
import {InitialConfig} from "./InitialConfig.sol";
import {Config} from "./Config.sol";
import {Utils} from "../library/Utils.sol";
import {IDebtToken} from "./interfaces/IDebtToken.sol";
import {ICommunityIssuance} from "../OSHI/interfaces/ICommunityIssuance.sol";
import {IRewardManager} from "../OSHI/interfaces/IRewardManager.sol";

contract Initializer is Initializable, AccessControlInternal,  OwnableInternal {
    using Utils for *;

    /**
     * @notice Initialize function for the SatoshiXAPP contract
     * @dev This function is called only once when the protocol is deployed
     * @param data The encoded data for the initializer
     */
    function init(bytes calldata data) external initializer {
        (address rewardManager, address debtToken, address communityIssuance, address sortedTrovesBeacon, address troveManagerBeacon) =
            abi.decode(data, (address, address, address, address, address));
        rewardManager.ensureNonzeroAddress();

        // set roles
        _setRoleAdmin(Config.OWNER_ROLE, Config.OWNER_ROLE);
        _setRoleAdmin(Config.GUARDIAN_ROLE, Config.OWNER_ROLE);
        _grantRole(Config.OWNER_ROLE, InitialConfig.OWNER);
        _grantRole(Config.GUARDIAN_ROLE, InitialConfig.GUARDIAN);
        _setOwner(InitialConfig.OWNER);

        AppStorage.Layout storage s = AppStorage.layout();
        s.feeReceiver = InitialConfig.FEE_RECEIVER;
        s.rewardManager = IRewardManager(rewardManager);
        s.debtToken = IDebtToken(debtToken);
        s.communityIssuance = ICommunityIssuance(communityIssuance);
        s.startTime = block.timestamp;

        /* factory facet */
        // set beacons
        s.sortedTrovesBeacon = IBeacon(sortedTrovesBeacon);
        s.troveManagerBeacon = IBeacon(troveManagerBeacon);
    }
}
