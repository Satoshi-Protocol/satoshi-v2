// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDIAOracleV2 } from "./interfaces/IDIAOracleV2.sol";
import { IPriceFeed } from "./interfaces/IPriceFeed.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Partial interface of wstBTC
 *        Source:
 *        https://scan-mainnet.bevm.io/token/0x2967E7Bb9DaA5711Ac332cAF874BD47ef99B3820
 */
interface IWstBTCPartial {
    function stBtcPerToken() external view returns (uint256);
}

/**
 * @title PriceFeed Contract to integrate wstBTC with DIA Oracle
 *        Convert data from interface of wstBTC with DIA Oracle to Satoshi's IPriceFeed
 */
contract PriceFeedWstBTCWithDIAOracle is IPriceFeed, Ownable {
    uint256 internal constant STBTC_PER_WSTBTC_BASE = 1e18;

    IDIAOracleV2 internal immutable _source;
    uint8 internal immutable _decimals;
    IWstBTCPartial internal immutable _wstBTC;

    string internal _key;
    uint256 public maxTimeThreshold;

    constructor(
        IDIAOracleV2 source_,
        uint8 decimals_,
        string memory key_,
        uint256 _maxTimeThreshold,
        IWstBTCPartial wstBTC_
    )
        Ownable(msg.sender)
    {
        _source = source_;
        _decimals = decimals_;
        _key = key_;
        maxTimeThreshold = _maxTimeThreshold;
        _wstBTC = wstBTC_;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external returns (uint256) {
        (uint128 price, uint128 lastUpdated) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);
        if (block.timestamp - uint256(lastUpdated) > maxTimeThreshold) {
            revert PriceTooOld();
        }

        uint256 wstBtcPrice = (uint256(price) * _wstBTC.stBtcPerToken()) / STBTC_PER_WSTBTC_BASE;
        return wstBtcPrice;
    }

    function fetchPriceUnsafe() external returns (uint256, uint256) {
        (uint128 price, uint128 lastUpdated) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);

        uint256 wstBtcPrice = (uint256(price) * _wstBTC.stBtcPerToken()) / STBTC_PER_WSTBTC_BASE;
        return (wstBtcPrice, lastUpdated);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
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
