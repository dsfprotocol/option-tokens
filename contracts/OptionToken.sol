pragma solidity ^0.5;

import "./VariableSupplyToken.sol";


contract OptionToken is VariableSupplyToken {
    constructor(string memory _name, string memory _symbol) public {
        creator = msg.sender;
        name = _name;
        symbol = _symbol;
    }
}