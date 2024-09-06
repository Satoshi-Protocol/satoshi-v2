// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IXAppRouter {
    function callToXApp(bytes memory data) external;

    function callToPortal(uint64 destChainId, address to, bytes memory data, uint64 gasLimit) external;
}
