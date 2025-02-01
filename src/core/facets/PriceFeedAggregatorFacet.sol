// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlInternal} from "@solidstate/contracts/access/access_control/AccessControlInternal.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AppStorage} from "../AppStorage.sol";
import {IPriceFeedAggregatorFacet, OracleRecord} from "../interfaces/IPriceFeedAggregatorFacet.sol";
import {IPriceFeed} from "../../priceFeed/interfaces/IPriceFeed.sol";
import {Config} from "../Config.sol";

contract PriceFeedAggregatorFacet is IPriceFeedAggregatorFacet, AccessControlInternal {
    function setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) external onlyRole(Config.OWNER_ROLE) {
        _setPriceFeed(_token, _priceFeed);
    }

    function _setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) internal {
        if (address(_priceFeed) == address(0)) {
            revert InvalidPriceFeedAddress();
        }
        if (_priceFeed.fetchPrice() == uint256(0)) {
            revert InvalidFeedResponse(_priceFeed);
        }

        AppStorage.Layout storage s = AppStorage.layout();
        OracleRecord memory record = OracleRecord({priceFeed: _priceFeed, decimals: _priceFeed.decimals()});
        s.oracleRecords[_token] = record;

        emit NewOracleRegistered(_token, _priceFeed);
    }

    // Public functions -------------------------------------------------------------------------------------------------

    function fetchPrice(IERC20 _token) public returns (uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        OracleRecord memory oracle = s.oracleRecords[_token];

        uint256 rawPrice = oracle.priceFeed.fetchPrice();
        uint8 decimals = oracle.decimals;

        uint256 scaledPrice;
        if (decimals == Config.PRICE_TARGET_DIGITS) {
            scaledPrice = rawPrice;
        } else if (decimals < Config.PRICE_TARGET_DIGITS) {
            scaledPrice = rawPrice * (10 ** (Config.PRICE_TARGET_DIGITS - decimals));
        } else {
            scaledPrice = rawPrice / (10 ** (decimals - Config.PRICE_TARGET_DIGITS));
        }
        return scaledPrice;
    }

    function fetchPriceUnsafe(IERC20 _token) external returns (uint256, uint256) {
        AppStorage.Layout storage s = AppStorage.layout();
        OracleRecord memory oracle = s.oracleRecords[_token];

        (uint256 rawPrice, uint256 updatedAt) = oracle.priceFeed.fetchPriceUnsafe();
        uint8 decimals = oracle.decimals;

        uint256 scaledPrice;
        if (decimals == Config.PRICE_TARGET_DIGITS) {
            scaledPrice = rawPrice;
        } else if (decimals < Config.PRICE_TARGET_DIGITS) {
            scaledPrice = rawPrice * (10 ** (Config.PRICE_TARGET_DIGITS - decimals));
        } else {
            scaledPrice = rawPrice / (10 ** (decimals - Config.PRICE_TARGET_DIGITS));
        }
        return (scaledPrice, updatedAt);
    }

    function oracleRecords(IERC20 _token) external view returns (IPriceFeed priceFeed, uint8 decimals) {
        AppStorage.Layout storage s = AppStorage.layout();
        OracleRecord memory record = s.oracleRecords[_token];
        return (record.priceFeed, record.decimals);
    }
}
