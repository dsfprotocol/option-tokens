// SPDX-License-Identifier: MIT
pragma solidity ^0.7;


contract OptionTokenFactory {
    address public base;
    address public underlying;

    constructor(address _base, address _underlying) {
        base = _base;
        underlying = _underlying;
    }

    
}