pragma solidity ^0.5;

import "./Cloner.sol";
import "./ETHCallOptionToken.sol";
import "./ProxyInterface.sol";


contract OptionTokenFactory is Cloner {
    address public template;

    constructor() public {
        template = address(new ETHCallOptionToken());
    }

    function createToken() public returns (address) {
        address token = clone(template);
        ProxyInterface(msg.sender).optionTokenWasCloned(token);
        require(ETHCallOptionToken(token).initialized());
        return token;
    }
}