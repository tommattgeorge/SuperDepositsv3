// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ISuperDeposit {

    function depositToAave(
        address recepient        
    ) external;

    function _getFlow(
        address sender
    ) external view returns(uint256, int96);

    function removeAddress(uint toRemove) external;

    function getUserAddress(
        uint256 index
    ) view external returns(address);

    function getTotalAddresses() external view returns(uint);

    function addKeeperContractAddress(address _keeperCon) external;

    function _updateCurentInfo(
        address owner,
        uint startTime,
        int96 flowRate
    ) external;

    function getAddressTokenInfo(
        address user
    ) external view returns(
        uint256 startTime,
        int96 flowRate,
        uint256 amountAccumunated,
        uint256 freequency
    );
}