pragma solidity ^0.5;

import "./Cloner.sol";
import "./ETHCallOptionToken.sol";
import "./ETHPutOptionToken.sol";
import "./ProxyInterface.sol";


contract OptionTokenFactory is Cloner {
    address public callTemplate;
    address public putTemplate;

    constructor() public {
        callTemplate = address(new ETHCallOptionToken());
        putTemplate = address(new ETHPutOptionToken());
    }

    function createCallOptionToken() public returns (address) {
        return createOptionToken(callTemplate);
    }

    function createPutOptionToken() public returns (address) {
        return createOptionToken(putTemplate);
    }

    function createOptionToken(address template) internal returns (address) {
        address token = clone(template);
        ProxyInterface(msg.sender).optionTokenWasCloned(token);
        require(ETHCallOptionToken(token).initialized());
        return token;
    }
}