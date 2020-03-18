pragma solidity ^0.5;


interface Auction {
    function receiveETH(uint256 expectingUSD) external payable;
    function receiveUSD(uint256 expectingETH) external;
}