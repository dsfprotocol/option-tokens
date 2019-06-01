pragma solidity ^0.5;

import "./ERC20Variables.sol";

contract ERC20 is ERC20Variables {

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transferBalance(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(allowance >= _value);
        _transferBalance(_from, _to, _value);
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferToContract(address _to, uint256 _value, bytes memory data) public returns (bool) {
        _transferBalance(msg.sender, _to, _value);
        bytes4 sig = bytes4(keccak256("receiveTokens(address,uint256,bytes)"));
        (bool result,) = _to.call(abi.encodePacked(sig, msg.sender, _value, data));
        require(result);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function _transferBalance(address _from, address _to, uint _value) internal {
        require(balances[_from] >= _value);
        balances[_from] -= _value;
        balances[_to] += _value;
    }
}