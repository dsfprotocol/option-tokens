pragma solidity ^0.5;

import "./VariableSupplyToken.sol";


// we don't store much state here either
contract DSFTokenMock is VariableSupplyToken {
    constructor() public {
        creator = msg.sender;
        name = "Decentralized Settlement Facility Token";
        symbol = "DSF";

        // this needs to be here to avoid zero initialization of token rights.
        totalSupply = 100 ether;
        balances[msg.sender] = 100 ether;
    }
}