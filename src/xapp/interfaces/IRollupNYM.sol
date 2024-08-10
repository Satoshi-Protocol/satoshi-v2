// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRollupNYM {
    error ZeroAddress();
    error ZeroAmount();
    error InvalidChainId();
    error AssetNotSupported(address asset);
    error NotEnoughDebtToken(uint256 debtBalance, uint256 amount);
    error AssetNotEnough(uint256 assetAmount, uint256 _amount);
    error NotPrivileged(address vault);
    error InvalidSourceChainSender(address, address);
    error InvalidSourceChain(uint64, uint64);

    event TokenTransferred(address token, address vault, uint256 amount);

    function swapIn(address asset, address receiver, uint256 assetAmount, uint64 destChainId) external payable;

    function scheduleSwapOut(address asset, uint256 amount) external payable;

    function withdraw(address asset, uint256 amount) external payable;

    function transferFund() external;

    function transferAsset(address asset, address to, uint256 amount) external;

    function initialize(address portal, address _omniChainNYM, address debtToken_, address _priceFeedAggregator)
        external;

    function setAssetSupported(address asset, bool supported) external;

    function setSupportedChainId(uint64 chainId, bool supported) external;
}
