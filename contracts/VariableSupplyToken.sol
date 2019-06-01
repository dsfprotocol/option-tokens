pragma solidity ^0.5;

import "./ERC20.sol";


contract VariableSupplyToken is ERC20 {
    function grant(address to, uint256 amount) public returns (bool) {
        require(msg.sender == creator);
        require(balances[to] + amount >= amount);
        balances[to] += amount;
        totalSupply += amount;
        return true;
    }

    function burn(address from, uint amount) public returns (bool) {
        require(msg.sender == creator);
        require(balances[from] >= amount);
        balances[from] -= amount;
        totalSupply -= amount;
        return true;
    }
}