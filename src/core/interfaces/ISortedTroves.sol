// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITroveManager} from "./ITroveManager.sol";

/// @title ISortedTroves
/// @notice Interface for managing a sorted list of troves based on their NICR (Nominal Individual Collateral Ratio).
interface ISortedTroves {
    /// @notice Emitted when a node is added to the list.
    /// @param _id The address of the node added.
    /// @param _NICR The NICR of the node added.
    event NodeAdded(address _id, uint256 _NICR);

    /// @notice Emitted when a node is removed from the list.
    /// @param _id The address of the node removed.
    event NodeRemoved(address _id);

    /// @notice Emitted when the Trove Manager is set.
    /// @param _troveManager The address of the Trove Manager contract.
    event SetTroveManager(address _troveManager);

    /// @notice Initializes the contract with the given owner.
    /// @param owner The address of the owner.
    function initialize(address owner) external;

    /// @notice Inserts a node into the list.
    /// @param _id The address of the node to insert.
    /// @param _NICR The NICR of the node to insert.
    /// @param _prevId The address of the previous node in the list.
    /// @param _nextId The address of the next node in the list.
    function insert(address _id, uint256 _NICR, address _prevId, address _nextId) external;

    /// @notice Re-inserts a node into the list with a new NICR.
    /// @param _id The address of the node to re-insert.
    /// @param _newNICR The new NICR of the node.
    /// @param _prevId The address of the previous node in the list.
    /// @param _nextId The address of the next node in the list.
    function reInsert(address _id, uint256 _newNICR, address _prevId, address _nextId) external;

    /// @notice Removes a node from the list.
    /// @param _id The address of the node to remove.
    function remove(address _id) external;

    /// @notice Sets the configuration for the Trove Manager.
    /// @param _troveManager The address of the Trove Manager contract.
    function setConfig(ITroveManager _troveManager) external;

    /// @notice Checks if a node exists in the list.
    /// @param _id The address of the node to check.
    /// @return True if the node exists, false otherwise.
    function contains(address _id) external view returns (bool);

    /// @notice Returns the data of the list.
    /// @return head The address of the head node.
    /// @return tail The address of the tail node.
    /// @return size The current size of the list.
    function data() external view returns (address head, address tail, uint256 size);

    /// @notice Finds the insert position for a node with a given NICR.
    /// @param _NICR The NICR of the node to insert.
    /// @param _prevId The address of the previous node in the list.
    /// @param _nextId The address of the next node in the list.
    /// @return The addresses of the previous and next nodes for the insert position.
    function findInsertPosition(uint256 _NICR, address _prevId, address _nextId)
        external
        view
        returns (address, address);

    /// @notice Gets the first node in the list.
    /// @return The address of the first node.
    function getFirst() external view returns (address);

    /// @notice Gets the last node in the list.
    /// @return The address of the last node.
    function getLast() external view returns (address);

    /// @notice Gets the next node in the list for a given node.
    /// @param _id The address of the current node.
    /// @return The address of the next node.
    function getNext(address _id) external view returns (address);

    /// @notice Gets the previous node in the list for a given node.
    /// @param _id The address of the current node.
    /// @return The address of the previous node.
    function getPrev(address _id) external view returns (address);

    /// @notice Gets the size of the list.
    /// @return The current size of the list.
    function getSize() external view returns (uint256);

    /// @notice Checks if the list is empty.
    /// @return True if the list is empty, false otherwise.
    function isEmpty() external view returns (bool);

    /// @notice Gets the Trove Manager contract.
    /// @return The address of the Trove Manager contract.
    function troveManager() external view returns (ITroveManager);

    /// @notice Validates the insert position for a node with a given NICR.
    /// @param _NICR The NICR of the node to insert.
    /// @param _prevId The address of the previous node in the list.
    /// @param _nextId The address of the next node in the list.
    /// @return True if the insert position is valid, false otherwise.
    function validInsertPosition(uint256 _NICR, address _prevId, address _nextId) external view returns (bool);
}

// Information for a node in the list
struct Node {
    bool exists; ///< Indicates if the node exists in the list.
    address nextId; ///< Id of next node (smaller NICR) in the list.
    address prevId; ///< Id of previous node (larger NICR) in the list.
}

// Information for the list
struct Data {
    address head; ///< Head of the list. Also the node in the list with the largest NICR.
    address tail; ///< Tail of the list. Also the node in the list with the smallest NICR.
    uint256 size; ///< Current size of the list.
    mapping(address => Node) nodes; ///< Track the corresponding ids for each node in the list.
}
