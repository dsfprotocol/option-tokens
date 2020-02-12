pragma solidity ^0.5;


contract DefaultBalanceToken {
    int256 constant public DEFAULT_BALANCE = 1000000 ether;
    uint256 constant public MAX_UINT256 = 2**256 - 1;

    mapping(address => int256) public _balances;

    mapping(address => mapping(address => uint)) public allowed;

    uint8 public constant decimals = 18;
    string public name;
    string public symbol;
    uint constant public totalSupply = MAX_UINT256;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function balances(address _spender) public view returns (uint256) {
        return balanceOf(_spender);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return uint256(DEFAULT_BALANCE + _balances[_owner]);
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf(msg.sender) >= _value);
        _balances[msg.sender] -= int256(_value);
        _balances[_to] += int256(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allow = allowed[_from][msg.sender];
        require(allow >= _value);
        require(balanceOf(_from) >= _value);
        _balances[_from] -= int256(_value);
        _balances[_to] += int256(_value);
        if (allow < MAX_UINT256) {
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
}