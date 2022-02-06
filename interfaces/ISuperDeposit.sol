// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ISuperDeposit {

    function depositToAave(
        address token,
        address recepient        
    ) external;

    function _getFlow(
        address acceptedToken,
        address sender,
        address recepient
    ) external view returns(uint256, int96);

    function removeAddress(address token, uint toRemove) external;

    function getTokenUserAddress(
        address token,
        uint256 index
    ) view external returns(address);

    function getTotalAddresses(address token) external view returns(uint);

    function getTokens(uint256 index) external view returns(address);

    function getTotalTokens() external view returns(uint256);

    function _updateCurentInfo(
        address acceptedToken,
        address owner,
        uint startTime,
        int96 flowRate
    ) external;

    function getAddressTokenInfo(
        address token,
        address user
    ) external view returns(
        uint256 startTime,
        int96 flowRate,
        uint256 amountAccumunated,
        uint256 freequency
    );
}