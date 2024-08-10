// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRollupMinter {
    error InvalidSourceChainSender(address, address);
    error InvalidSourceChain(uint64, uint64);

    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}
