pragma solidity ^0.8.20;

interface IRestakingVault {
    struct WithdrawOrder {
        uint256 index;
        uint256 amount;
        address owner;
        bool used;
    }

    function deposit(uint256 amount) external;

    function requestWithdraw(uint256 amount) external;

    function claim(uint256[] memory indexes) external;

    function getOrdersByOwner(address owner) external view returns (WithdrawOrder[] memory);
}
