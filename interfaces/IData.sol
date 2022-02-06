// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IData {

    function getEncoding(int96 flowRate, address token) external view returns(bytes memory);
}