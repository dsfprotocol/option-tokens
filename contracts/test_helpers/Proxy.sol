pragma solidity ^0.5;

import "../OptionTokenFactory.sol";
import "../ETHCallOptionToken.sol";
import "../


contract Proxy {
    constructor(address _factory) public {
        OptionTokenFactory f = OptionTokenFactory(_factory);

        f.createPutOptionToken()
    }
}