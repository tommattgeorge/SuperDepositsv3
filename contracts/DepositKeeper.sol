// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "../interfaces/ISuperDeposit.sol";
contract DepositKeeper is KeeperCompatibleInterface {

    ISuperDeposit superDeposit;

    mapping(address => uint) private tokenAddresses;
    constructor(ISuperDeposit _superDeposit) {
        superDeposit = _superDeposit;
    }
/*
    //we get tokens
    superDeposit.getTotalTokens();
    //we keep up to date with current addresses

    superDeposit.getTotalAddresses(token);

    //we getTokens
    superDeposit.getTokens(index);

    //we get active token user address

    superDeposit.getTokenUserAddress(token, index);
*/


    //we check flowFarte

    //superDeposit._getFlow(acceptedToken, sender, recepient);

    //we get frequency of deposit
    function _getAddressFreequency(address superToken, address user) private view returns(uint, uint) {
        (uint start,,,uint frequency) = superDeposit.getAddressTokenInfo(superToken, user);
        return (start, frequency);
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (
        bool upkeepNeeded, bytes memory performData
    ) { 
        for (uint i = 0; i < superDeposit.getTotalTokens(); i++) {
            address token = superDeposit.getTokens(i);
            for (uint p = 0; p < superDeposit.getTotalAddresses(token); p++) {
                address user = superDeposit.getTokenUserAddress(token, p);
                (uint begining, uint freq) = _getAddressFreequency(token, user);
                if ((begining + freq) >= block.timestamp) {
                    upkeepNeeded = true;
                    uint purpose = 1;
                    return (true, abi.encodePacked(token, p, purpose));
                }
                (,int96 flowRate) = superDeposit._getFlow(token, user, address(superDeposit));
                if (flowRate == 0) {
                    upkeepNeeded = true;
                    uint purpose = 2;
                    return (true, abi.encodePacked(token, p, purpose));
                }
            }
        }
        
        performData = checkData;
        
    }
    
    function performUpkeep(bytes calldata performData) external override {
        (address token, uint256 index, uint purpose) = abi.decode(performData, (address, uint256, uint256));
        address user = superDeposit.getTokenUserAddress(token, index);
        if (purpose == 1) {
            superDeposit.depositToAave(token, user);
        } 
        if (purpose == 2) {
            superDeposit._updateCurentInfo(token, user, block.timestamp, 0);
            superDeposit.removeAddress(token, index);
        }
    }
    

}