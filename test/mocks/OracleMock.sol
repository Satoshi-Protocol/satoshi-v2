// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AggregatorV3Interface } from "../../src/priceFeed/interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "../../src/priceFeed/interfaces/IPriceFeed.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

struct RoundData {
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
}

contract OracleMock is AggregatorV3Interface, IPriceFeed, Ownable {
    string private constant _description = "Mock Oracle";
    uint8 private immutable _decimals;
    uint256 private immutable _version;
    uint80 private _lastRoundId;
    mapping(uint80 => RoundData) private _roundData;
    uint256 public maxTimeThreshold;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    /* deciamls = 8, version = 1 */
    constructor(uint8 decimals_, uint256 version_) Ownable(msg.sender) {
        _decimals = decimals_;
        _version = version_;
        maxTimeThreshold = 86_400;
        emit MaxTimeThresholdUpdated(86_400);
    }

    function description() external pure override returns (string memory) {
        return _description;
    }

    function decimals() external view override(AggregatorV3Interface, IPriceFeed) returns (uint8) {
        return _decimals;
    }

    function version() external view override returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory roundData = _roundData[_roundId];
        return (_roundId, roundData.answer, roundData.startedAt, roundData.updatedAt, roundData.answeredInRound);
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory roundData = _roundData[_lastRoundId];
        return (_lastRoundId, roundData.answer, roundData.startedAt, roundData.updatedAt, roundData.answeredInRound);
    }

    function updateRoundData(RoundData memory roundData) external onlyOwner {
        _lastRoundId++;
        _roundData[_lastRoundId] = roundData;
        emit AnswerUpdated(roundData.answer, _lastRoundId, roundData.updatedAt);
    }

    function getUpdateFee(bytes[] calldata) external pure returns (uint256) {
        return 0;
    }

    function updatePriceFeeds(bytes[] calldata) external {
        // do nothing
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        if (block.timestamp - updatedAt > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        (, int256 price,, uint256 updatedAt,) = latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        return (uint256(price), updatedAt);
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        if (_maxTimeThreshold <= 120) {
            revert InvalidMaxTimeThreshold();
        }

        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function source() external view returns (address) {
        return address(this);
    }
}
