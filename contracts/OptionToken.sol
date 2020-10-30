// SPDX-License-Identifier: MIT
pragma solidity ^0.7;

import "./ERC20.sol";


contract OptionToken is ERC20 {
    address public base;
    uint256 public expiration;
    bool    public isCall;
    uint256 public strike;
    address public underlying;

    mapping(address => uint256) public writers;

    constructor(
        address _base, 
        uint256 _expiration, 
        bool    _isCall, 
        uint256 _strike, 
        address _underlying
    ) {
        base = _base;
        expiration = _expiration;
        isCall = _isCall;
        strike = _strike;
        underlying = _underlying;
    }

    function write(uint256 amount) public {
        if (isCall) {
            _transferUnderlying(amount);
        } else {            
            _transferBase(amount);
        }
        balances[msg.sender] += amount;
    }

    function close(uint256 amount) public {
        require(amount <= balances[msg.sender] && amount <= writers[msg.sender]);
        writers[msg.sender] -= amount;
        balances[msg.sender] -= amount;
        if (isCall) {
            _payUnderlying(amount);
        } else {
            _payBase(amount);
        }
    }

    function exercise(uint256 amount) public {
        require(amount <= balances[msg.sender]);
        if (isCall) {
            _transferBase(amount);
            _payUnderlying(amount);            
        } else {
            _transferUnderlying(amount);
            _payBase(amount);
        }
        balances[msg.sender] -= amount;
    }

    function settle() public {
        // Settlement model to be determined
    }

    function _payBase(uint256 amount) internal {
        ERC20(base).transfer(msg.sender, amount * strike / 1 ether);
    }

    function _payUnderlying(uint256 amount) internal {
        ERC20(base).transfer(msg.sender, amount);
    }

    function _transferBase(uint256 amount) internal {
        ERC20(base).transferFrom(msg.sender, address(this), amount * strike / 1 ether);
    }

    function _transferUnderlying(uint256 amount) internal {
        ERC20(underlying).transferFrom(msg.sender, address(this), amount);
    }
}