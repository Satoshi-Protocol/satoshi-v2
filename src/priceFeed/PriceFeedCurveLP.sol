// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

interface ICurvePool {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable returns (uint256);
    function remove_liquidity(uint256 amount, uint256[2] memory min_amounts) external returns (uint256);
    function get_virtual_price() external view returns (uint256);
}

/**
 * @title PriceFeed Contract to integrate with CurveLP
 */
contract PriceFeedCurveLPOracle is Ownable {
    ICurvePool internal immutable _source;
    uint8 internal immutable _decimals;

    constructor(address source_, uint8 decimals_) Ownable(msg.sender) {
        _source = ICurvePool(source_);
        _decimals = decimals_;
    }

    function fetchPrice() external returns (uint256) {
        // remove liquidity 0 to prevent price manipulation
        uint256[2] memory amounts;
        ICurvePool(_source).remove_liquidity(0, amounts);
        uint256 price = ICurvePool(_source).get_virtual_price();
        return price;
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        uint256 price = ICurvePool(_source).get_virtual_price();
        return (price, 0);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function source() external view returns (address) {
        return address(_source);
    }
}
