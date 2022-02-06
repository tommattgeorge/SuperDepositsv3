// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

//import {SuperAppBase} from "@superfluid/apps/SuperAppBase.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";

contract DataGiver {

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa
    ) {
        _host = host;
        _cfa = cfa;
    }

    function getEncoding(int96 flowRate, ISuperToken _acceptedToken, address receiver) public view returns(bytes memory){
        return abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                receiver,
                flowRate,
                new bytes(0) // placeholder
            );
    }
}