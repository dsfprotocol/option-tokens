pragma solidity ^0.5;


contract ERC20 {
    uint256 constant public MAX_UINT256 = 2**256 - 1;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    uint8 public constant decimals = 18;
    string public name;
    string public symbol;
    uint public totalSupply;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    event Created(address creator, uint supply);

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transferBalance(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allow = allowed[_from][msg.sender];
        require(allow >= _value);
        _transferBalance(_from, _to, _value);
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