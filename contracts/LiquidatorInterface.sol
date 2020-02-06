pragma solidity ^0.5;


contract LiquidatorInterface {
    function receiveETH() public payable;
    function receiveUSD(uint256 amount) public;
}