pragma solidity ^0.5;

import "./ERC20.sol";
import "./Math.sol";
import "./LiquidatorInterface.sol";

library FactoryAddress {}
library USD {}
library DSF {}

interface Factory {
    function getTokenName(bool isCall, uint256 expiration, uint256 strike) external returns (string memory);
    function getTokenSymbol(bool isCall, uint256 expiration, uint256 strike) external returns (string memory);
}


contract OptionToken is ERC20, Math {
    bool public initialized;
    // address public factory;

    uint256 public expiration;
    uint256 public strike;

    mapping(address => uint256) public writers;

    uint256 public liquidated;
    uint256 public written;
    uint256 public redeemed;

    uint256 public constant SETTLEMENT_DURATION = 12 hours;

    ERC20 public usd;
    ERC20 public dsf;

    // called by Factory in same transaction as deploy
    function init(
        uint256 _expiration,
        uint256 _strike
    ) public returns (bool) {
        require(initialized == false);
        usd = ERC20(address(USD));
        dsf = ERC20(address(DSF));
        expiration = _expiration;
        strike = _strike;
        initialized = true;
        return true;
    }

    function approveAsOrigin(address spender, uint256 amount) internal returns (bool) {
        allowed[tx.origin][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveAndCall(address spender, uint256 quantity, bytes memory data) public returns (bool) {
        approve(spender, quantity);
        (bool result,) = spender.call(data);
        require(result && allowed[msg.sender][spender] < quantity);
        return true;
    }

    function settlementStart() public view returns (uint256) {
        return expiration;
    }

    function settlementEnd() public view returns (uint256) {
        return expiration + SETTLEMENT_DURATION;
    }
}