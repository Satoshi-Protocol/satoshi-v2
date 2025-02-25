// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "./interfaces/IPriceFeed.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 */
contract PriceFeedChainlink is IPriceFeed, Ownable {
    AggregatorV3Interface internal immutable _source;
    uint256 public maxTimeThreshold;

    constructor(AggregatorV3Interface source_, uint256 _maxTimeThreshold) Ownable(msg.sender) {
        _source = source_;
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = _source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        if (block.timestamp - updatedAt > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        (, int256 price,, uint256 updatedAt,) = _source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        return (uint256(price), updatedAt);
    }

    function decimals() external view returns (uint8) {
        return _source.decimals();
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        if (_maxTimeThreshold <= 120) {
            revert InvalidMaxTimeThreshold();
        }

        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function source() external view returns (address) {
        return address(_source);
    }
}
