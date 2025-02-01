// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceFeed} from "../../priceFeed/interfaces/IPriceFeed.sol";

struct OracleRecord {
    IPriceFeed priceFeed;
    uint8 decimals;
}

interface IPriceFeedAggregatorFacet {
    /**
     * @notice Emitted when a new oracle is registered.
     * @param token The ERC20 token associated with the oracle.
     * @param priceFeed The price feed contract for the oracle.
     */
    event NewOracleRegistered(IERC20 indexed token, IPriceFeed indexed priceFeed);

    // Custom Errors --------------------------------------------------------------------------------------------------

    /**
     * @notice Error indicating an invalid price feed address.
     */
    error InvalidPriceFeedAddress();

    /**
     * @notice Error indicating an invalid response from the price feed.
     * @param priceFeed The price feed contract that returned an invalid response.
     */
    error InvalidFeedResponse(IPriceFeed priceFeed);

    /**
     * @notice Fetches the price of a given token.
     * @param _token The ERC20 token for which the price is to be fetched.
     * @return The price of the token in the smallest unit.
     */
    function fetchPrice(IERC20 _token) external returns (uint256);

    /**
     * @notice Fetches the price of a given token without safety checks.
     * @param _token The ERC20 token for which the price is to be fetched.
     * @return The price of the token and the timestamp of the price.
     */
    function fetchPriceUnsafe(IERC20 _token) external returns (uint256, uint256);

    /**
     * @notice Sets the price feed for a given token.
     * @param _token The ERC20 token for which the price feed is to be set.
     * @param _priceFeed The price feed contract to be associated with the token.
     */
    function setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) external;

    /**
     * @notice Returns the oracle record for a given token.
     * @param _token The ERC20 token for which the oracle record is to be retrieved.
     * @return priceFeed The price feed contract associated with the token.
     * @return decimals The number of decimals used by the price feed.
     */
    function oracleRecords(IERC20 _token) external view returns (IPriceFeed priceFeed, uint8 decimals);
}
