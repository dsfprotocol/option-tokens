pragma solidity ^0.5;


contract ProxyInterface {
    function optionTokenWasCloned(address token) public returns (bool);
}