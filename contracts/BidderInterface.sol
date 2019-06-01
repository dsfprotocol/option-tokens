pragma solidity ^0.5;


contract BidderInterface {
    function receiveETH(address series, uint256 amount) public;
    function receiveUSD(address series, uint256 amount) public;
}