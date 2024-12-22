// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IRewardManager} from "../../OSHI/interfaces/IRewardManager.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {ICommunityIssuance} from "../../OSHI/interfaces/ICommunityIssuance.sol";

interface ICoreFacet {
    /// @notice Emitted when the reward manager is set
    /// @param rewardManager The address of the reward manager
    event RewardManagerSet(address rewardManager);

    /// @notice Emitted when the fee receiver is set
    /// @param feeReceiver The address of the fee receiver
    event FeeReceiverSet(address feeReceiver);

    /// @notice Emitted when the guardian is set
    /// @param guardian The address of the guardian
    event GuardianSet(address guardian);

    /// @notice Emitted when the protocol is paused
    event Paused();

    /// @notice Emitted when the protocol is unpaused
    event Unpaused();

    /// @notice Sets the fee receiver address
    /// @param _feeReceiver The address to set as the fee receiver
    function setFeeReceiver(address _feeReceiver) external;

    /// @notice Sets the reward manager address
    /// @param _rewardManager The address to set as the reward manager
    function setRewardManager(address _rewardManager) external;

    /// @notice Sets the paused state of the protocol
    /// @param _paused The boolean value to set the paused state
    function setPaused(bool _paused) external;

    /// @notice Returns the address of the fee receiver
    /// @return The address of the fee receiver
    function feeReceiver() external view returns (address);

    /// @notice Returns the reward manager interface
    /// @return The IRewardManager interface
    function rewardManager() external view returns (IRewardManager);

    /// @notice Returns the paused state of the protocol
    /// @return A boolean indicating if the protocol is paused
    function paused() external view returns (bool);

    /// @notice Returns the start time of the protocol
    /// @return The start time as a uint256
    function startTime() external view returns (uint256);

    /// @notice Returns the debt token interface
    /// @return The IDebtToken interface
    function debtToken() external view returns (IDebtToken);

    /// @notice Returns the gas compensation amount
    /// @return The gas compensation as a uint256
    function gasCompensation() external view returns (uint256);

    /// @notice Returns the sorted troves beacon interface
    /// @return The IBeacon interface for sorted troves
    function sortedTrovesBeacon() external view returns (IBeacon);

    /// @notice Returns the trove manager beacon interface
    /// @return The IBeacon interface for the trove manager
    function troveManagerBeacon() external view returns (IBeacon);

    /// @notice Returns the community issuance interface
    /// @return The ICommunityIssuance interface
    function communityIssuance() external view returns (ICommunityIssuance);
}
