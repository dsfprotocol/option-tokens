pragma solidity ^0.5;

import "./ERC20.sol";
import "./Math.sol";
import "./LiquidatorInterface.sol";

library FactoryAddress {}

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

    // constructor(address _factory) public {
    //     factory = _factory;
    // }

    // called by Factory in same transaction as deploy
    function init(
        uint256 _expiration,
        uint256 _strike
    ) public returns (bool) {
        require(initialized == false);
        usd = ERC20(0x4F678ceBFe01CF0A111600b3d0AFC27885aA578d);
        dsf = ERC20(0x9F4CA569De4c030a0afFDfB321cC553E1426A1bF);
        expiration = _expiration;
        strike = _strike;
        initialized = true;
        return true;
    }

    function settlementStart() public view returns (uint256) {
        return expiration;
    }

    function settlementEnd() public view returns (uint256) {
        return expiration + SETTLEMENT_DURATION;
    }
}