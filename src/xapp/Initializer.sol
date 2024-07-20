// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@solidstate/contracts/security/initializable/Initializable.sol";
import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {Ownable} from "@solidstate/contracts/access/ownable/Ownable.sol";
import {AppStorage} from "./storages/AppStorage.sol";
import {InitialConfig} from "./InitialConfig.sol";
import {Config} from "./Config.sol";
import {Utils} from "../library/Utils.sol";
import {IDebtToken} from "./interfaces/IDebtToken.sol";

contract Initializer is Ownable, Initializable, AccessControlInternal {
    using Utils for *;

    /**
     * @notice Initialize function for the SatoshiXAPP contract
     * @dev This function is called only once when the protocol is deployed
     * @param data The encoded data for the initializer
     */
    function init(bytes calldata data) external initializer {
        (address rewardManager, address debtToken) = abi.decode(data, (address, address));
        rewardManager.ensureNonzeroAddress();

        // set roles
        _setRoleAdmin(Config.OWNER_ROLE, Config.OWNER_ROLE);
        _grantRole(Config.OWNER_ROLE, InitialConfig.OWNER);
        transferOwnership(InitialConfig.OWNER);

        AppStorage.Layout storage s = AppStorage.layout();
        s.owner = InitialConfig.OWNER;
        s.guardian = InitialConfig.GUARDIAN;
        s.feeReceiver = InitialConfig.FEE_RECEIVER;
        s.ownershipTransferDelay = InitialConfig.OWNERSHIP_TRANSFER_DELAY;
        s.rewardManager = rewardManager;
        s.startTime = block.timestamp;
        s.debtToken = IDebtToken(debtToken);

        s.gasCompensation = InitialConfig.DEBT_GAS_COMPENSATION;
    }
}
