// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPriceFeed } from "./interfaces/IPriceFeed.sol";
import { IOracle } from "@chainsight-management-oracle/contracts/interfaces/IOracle.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainsight
 *        Convert data from interface of Chainsight to Satoshi's IPriceFeed
 * @dev Reference:
 *   https://docs.chainsight.network/chainsight-oracle/oracle-contract
 *   https://github.com/horizonx-tech/chainsight-management-oracle/blob/main/
 */
contract PriceFeedChainsight is IPriceFeed, Ownable {
    IOracle internal immutable _source;
    uint256 public maxTimeThreshold;

    // var for Chainsight oracle
    address internal _sender;
    bytes32 internal _key;
    uint8 internal _decimals;

    event SenderUpdated(address indexed sender);
    event KeyUpdated(bytes32 indexed key);

    constructor(
        IOracle source_,
        uint256 _maxTimeThreshold,
        address sender_,
        bytes32 key_,
        uint8 decimals_
    )
        Ownable(msg.sender)
    {
        _source = source_;
        maxTimeThreshold = _maxTimeThreshold;
        _sender = sender_;
        _key = key_;
        _decimals = decimals_;

        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        (uint256 price, uint64 updatedAt) = _source.readAsUint256WithTimestamp(_sender, _key);
        if (price <= 0) revert InvalidPriceUInt256(price);
        if (block.timestamp - updatedAt > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        (uint256 price, uint64 updatedAt) = _source.readAsUint256WithTimestamp(_sender, _key);
        if (price <= 0) revert InvalidPriceUInt256(price);
        return (uint256(price), updatedAt);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        if (_maxTimeThreshold <= 0) {
            revert InvalidMaxTimeThreshold();
        }

        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function updateSender(address sender_) external onlyOwner {
        _sender = sender_;
        emit SenderUpdated(sender_);
    }

    function updateKey(bytes32 key_) external onlyOwner {
        _key = key_;
        emit KeyUpdated(key_);
    }

    function source() external view returns (address) {
        return address(_source);
    }
}
