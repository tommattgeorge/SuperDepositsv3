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
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/ILendingPool.sol";

contract SuperDeposit {

    address DAI;
    
    ILendingPoolAddressesProvider private provider = ILendingPoolAddressesProvider(
        address(0x88757f2f99175387aB4C6a4b3067c77A695b0349)
    ); //mumbai 0x178113104fEcbcD7fF8669a0150721e231F0FD4B // kovan 0x88757f2f99175387aB4C6a4b3067c77A695b0349
    ILendingPool private lendingPool = ILendingPool(provider.getLendingPool());

    IConstantFlowAgreementV1 private cfa;
    ISuperfluid private host;

    address public keeperContract;
    address[] private acceptedTokens;

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

    mapping(ISuperToken => IERC20) private superTokeToNormal;

    mapping(address => mapping(ISuperToken => FlowrateInfo)) private addressFlowRate;

    mapping(string => TokenAndSuper) private tokenToSuperToke;//name of the token

    mapping(address => mapping(ISuperToken => uint256)) private tokenAddressindex;//index of the address in the token array

    mapping(ISuperToken => address[]) private tokenAddresses;//active addresses with streams
    
    constructor(IConstantFlowAgreementV1 _cfa, ISuperfluid _host) {
        cfa = _cfa;
        host = _host;
    }

    modifier onlyKeeperContract() {
        require(msg.sender == keeperContract);
        _;
    }

    function addKeeperContractAddress(address _keeperCon) external {
        require(keeperContract == address(0));
        keeperContract = _keeperCon;
    }

    function addAcceptedToken(ISuperToken token, string memory name, address normalToken) public {
        acceptedTokens.push(address(token));
        tokenToSuperToke[name] = TokenAndSuper(IERC20(normalToken), token);
        superTokeToNormal[token] = IERC20(normalToken);
    }
    function _getFlow(
        ISuperToken acceptedToken,
        address sender,
        address recepient
    ) public view returns (uint256, int96){
        (uint256 startTime, int96 outFloRate, ,) = cfa.getFlow(acceptedToken, sender, recepient);
        return (startTime, outFloRate);
    }

    function depositToAave(
        address token,
        address recepient        
    ) external onlyKeeperContract {
        uint256 amount = totalAccumulated(recepient, ISuperToken(token));
        ISuperToken(token).downgrade(amount);
        IERC20(superTokeToNormal[ISuperToken(token)]).approve(address(lendingPool), amount);
        lendingPool.deposit(address(superTokeToNormal[ISuperToken(token)]), amount, recepient, 0);
        //update the user details 
        uint256 feq = addressFlowRate[recepient][ISuperToken(token)].frequency;
        (,int96 outFlowRate, ,) = cfa.getFlow(ISuperToken(token),recepient, address(this));
        if (outFlowRate <= 0) {
            addressFlowRate[recepient][ISuperToken(token)] = FlowrateInfo(
                block.timestamp,
                outFlowRate,
                0,
                0
            );
        } else {
            addressFlowRate[recepient][ISuperToken(token)] = FlowrateInfo(
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

    function _updateCurentInfo(
        ISuperToken acceptedToken,
        address owner,
        uint startTime,
        int96 flowRate
    ) external onlyKeeperContract {
        //require(addressFlowRate[owner][acceptedToken].frequency != 0, "register a frequency first");
        uint256 totalAcc = ((block.timestamp - startTime) * toUint(flowRate));
        uint256 feq = addressFlowRate[owner][acceptedToken].frequency;
        addressFlowRate[owner][acceptedToken] = FlowrateInfo(startTime, flowRate, totalAcc, feq);
    }

    function totalAccumulated(
        address flowSender,
        ISuperToken acceptedToken
    ) public view returns(uint256) {
        (uint256 startTime, int96 flowRate) = _getFlow(acceptedToken, flowSender, address(this));
        uint256 totalAcc = ((block.timestamp - startTime) * toUint(flowRate));
        return totalAcc;
    }

    function downGradeForDeposit(string memory token, uint amount) private {
        ISuperToken supertoken = tokenToSuperToke[token]._token;
        supertoken.downgrade(amount);
    }

    function addAddress(ISuperToken token, uint256 frequency) public {
        ( uint start, int96 outFlowRate) = _getFlow(token, msg.sender, address(this));
        require(outFlowRate != 0);
        if (addressFlowRate[msg.sender][token].frequency == 0) {
            tokenAddresses[token].push(msg.sender);
        }
        addressFlowRate[msg.sender][token] = FlowrateInfo(start, outFlowRate, 0, frequency);
    }

    function removeAddress(ISuperToken token, uint toRemove) external onlyKeeperContract {
        uint size = tokenAddresses[token].length - 1;
        tokenAddresses[token][toRemove] = tokenAddresses[token][size];
        tokenAddresses[token].pop();
    }

    function getTotalAddresses(ISuperToken token) public view returns(uint256) {
        return tokenAddresses[token].length;
    }

    function getTokenUserAddress(ISuperToken token, uint256 index) external view returns(address) {
        return tokenAddresses[token][index];
    }

    function getTokens(uint256 index) external view returns(address) {
        return acceptedTokens[index];
    }

    function getTotalTokens() external view returns(uint256) {
        return acceptedTokens.length;
    }

    function getAddressTokenInfo(
        ISuperToken token,
        address user
    ) external view returns(
        uint256 startTime,
        int96 flowRate,
        uint256 amountAccumunated,
        uint256 frequency
    ) {
        uint duration = block.timestamp - addressFlowRate[user][token].startTime; 
        startTime = addressFlowRate[user][token].startTime; 
        flowRate = addressFlowRate[user][token].flowRate;
        amountAccumunated = totalAccumulated(user, token);
        frequency = addressFlowRate[user][token].frequency;
        return(startTime,flowRate,amountAccumunated,frequency);
    }

}