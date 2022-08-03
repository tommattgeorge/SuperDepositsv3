// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ISuperTokenFactory} from "@superfluid/interfaces/superfluid/ISuperTokenFactory.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";
import "../interfaces/DataTypes.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "../interfaces/IPool.sol";

contract SuperDeposit {

    address private aaveDAI;
    ISuperToken private _superDai;
    
    IPoolAddressesProvider private provider = IPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); //mumbai 0x178113104fEcbcD7fF8669a0150721e231F0FD4B // kovan 0x88757f2f99175387aB4C6a4b3067c77A695b0349
    IPool private Pool = IPool(provider.getPool());

    IConstantFlowAgreementV1 private cfa;

    address public keeperContract;
    //
    //address[] private acceptedTokens;

    struct FlowrateInfo {
        uint256 startTime;
        int96 flowRate;
        uint256 amountAccumunated;
        uint256 frequency;
    }

    struct TokenAndSuper {
        IERC20 token_;
        ISuperToken _token;
    }

    //mapping(ISuperToken => IERC20) private superTokeToNormal;

    mapping(address => FlowrateInfo) private addressFlowRate;

    address[] private tokenAddresses;//active addresses with streams
    mapping(address => uint256) private _toDeposit;
    
    constructor(
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _daix,
        address _dai
    ) {
        cfa = _cfa;
        aaveDAI = _dai;
        _superDai = _daix;
    }

    modifier onlyKeeperContract() {
        require(msg.sender == keeperContract);
        _;
    }

    function addKeeperContractAddress(address _keeperCon) external {
        require(keeperContract == address(0));
        keeperContract = _keeperCon;
    }
    
    function _getFlow(
        address sender
    ) public view returns (uint256, int96){
        (uint256 startTime, int96 outFloRate,,) = cfa.getFlow(_superDai, sender, address(this));
        return (startTime, outFloRate);
    }

    function depositToAave(
        address recepient        
    ) external onlyKeeperContract {
        _toDeposit[recepient] = _totalAccumulated(recepient);
        uint amount = _toDeposit[recepient];
        _superDai.downgrade(amount);
        IERC20(aaveDAI).approve(address(lendingPool), amount);
        Pool.deposit(aaveDAI, amount, recepient, 0);
        //update the user details 
        uint256 feq = addressFlowRate[recepient].frequency;
        (uint stop, int96 outFlowRate, ,) = cfa.getFlow(_superDai, recepient, address(this));
        if (outFlowRate <= 0) {
            addressFlowRate[recepient] = FlowrateInfo(
                stop,
                0,
                0,
                0
            );
        } else {
            addressFlowRate[recepient] = FlowrateInfo(
                block.timestamp,
                outFlowRate,
                0,
                feq
            );
        }
    }

    function toUint(int96 number) private pure returns(uint256) {
        int256 number1 = int256(number);
        return(uint256(number1));
    }

    function _totalAccumulated(
        address flowSender
    ) private view returns(uint) {
        uint256 startTime = addressFlowRate[flowSender].startTime;
        (uint start2, int96 flowRate,,) = cfa.getFlow(
            _superDai,
            flowSender,
            address(this)
        );
        if (flowrate <= 0) {
            return (start2 - startTime) * toUint(flowRate);
        } else {
            return ((block.timestamp - startTime) * toUint(flowRate));
        }
    }
    
    function totalAccumulated(
        address flowSender
    ) public view returns(uint256) {
        (uint256 startTime, int96 flowRate,,) = cfa.getFlow(_superDai, flowSender, address(this));
        uint256 totalAcc = ((block.timestamp - startTime) * toUint(flowRate));
        return totalAcc;
    }

    function addFreequency( uint256 frequency) public {
        ( uint start, int96 outFlowRate) = _getFlow(msg.sender);
        require(outFlowRate != 0);
        tokenAddresses.push(msg.sender);
        addressFlowRate[msg.sender] = FlowrateInfo(start, outFlowRate, 0, frequency);
    }

    function removeAddress(uint toRemove) external onlyKeeperContract {
        uint size = tokenAddresses.length - 1;
        tokenAddresses[toRemove] = tokenAddresses[size];
        tokenAddresses.pop();
    }

    function getTotalAddresses() public view returns(uint256) {
        return tokenAddresses.length;
    }

    function getUserAddress(uint256 index) external view returns(address) {
        return tokenAddresses[index];
    }
/*
    function getTokens(uint256 index) external view returns(address) {
        return acceptedTokens[index];
    }

    function getTotalTokens() external view returns(uint256) {
        return acceptedTokens.length;
    }
    */


    function getAddressTokenInfo(
        address user
    ) external view returns(
        uint256 startTime,
        int96 flowRate,
        uint256 amountAccumunated,
        uint256 frequency
    ) {
        uint duration = block.timestamp - addressFlowRate[user].startTime; 
        startTime = addressFlowRate[user].startTime; 
        flowRate = addressFlowRate[user].flowRate;
        amountAccumunated = totalAccumulated(user);
        frequency = addressFlowRate[user].frequency;
        return(startTime,flowRate,amountAccumunated,frequency);
    }

}
