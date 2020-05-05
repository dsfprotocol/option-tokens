pragma solidity ^0.5;

import "./Cloner.sol";
import "./ETHCallOptionToken.sol";
import "./ETHPutOptionToken.sol";
import "./ETHCallOptionTokenProxy.sol";
import "./ETHPutOptionTokenProxy.sol";
import "./OptionTokenNamesake.sol";


contract OptionTokenFactory is Cloner {
    mapping(uint128 => mapping(uint128 => address)) public calls;
    mapping(uint128 => mapping(uint128 => address)) public puts;

    address public callTemplate;
    address public putTemplate;
    ERC20 public usd;

    event OptionTokenCreated(address token, bool indexed isCall, uint128 indexed expiration, uint128 indexed strike);

    modifier receiveUSD(uint128 strike, uint128 amount) {
        uint128 cost = amount * strike / 1 ether;
        usd.transferFrom(msg.sender, address(this), cost);
        _;
    }

    constructor() public {
        callTemplate = address(new ETHCallOptionTokenProxy());
        putTemplate = address(new ETHPutOptionTokenProxy());
        usd = ERC20(address(USD));
    }

    function createCall(uint128 expiration, uint128 strike) public returns (address) {
        return address(findOrCreateCall(expiration, strike));
    }

    function writeCall(uint128 expiration, uint128 strike) public payable returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeAsOrigin.value(msg.value)();
    }

    function writeCallAndApprove(uint128 expiration, uint128 strike, address approve) public payable returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeAndApproveAsOrigin.value(msg.value)(approve);
    }

    function writeCallAndApproveAndCall(uint128 expiration, uint128 strike, address approve, bytes memory data) public payable returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeApproveAndCallAsOrigin.value(msg.value)(approve, data);
    }

    function createPut(uint128 expiration, uint128 strike) public returns (address) {
        return address(findOrCreatePut(expiration, strike));
    }

    function writePut(uint128 expiration, uint128 strike, uint128 amount) public receiveUSD(strike, amount) returns (address) {
        ETHPutOptionToken token = findOrCreatePut(expiration, strike);
        token.writeAsOrigin(amount);
    }

    function writePutAndApprove(uint128 expiration, uint128 strike, uint128 amount, address approve) public receiveUSD(strike, amount) returns (address) {
        ETHPutOptionToken token = findOrCreatePut(expiration, strike);
        token.writeAndApproveAsOrigin(amount, approve);
    }

    function writePutApproveAndCall(uint128 expiration, uint128 strike, uint128 amount, address approve, bytes memory data) public returns (address) {
        ETHPutOptionToken token = findOrCreatePut(expiration, strike);
        token.writeApproveAndCallAsOrigin(amount, approve, data);
    }

    function findOrCreateCall(uint128 expiration, uint128 strike) internal returns (ETHCallOptionToken) {
        require(expiration > now && expiration % 86400 - 43200 == 0 && strike % 5 ether == 0 && strike > 0 ether && strike < 100000 ether);
        address token = calls[expiration][strike];
        if (token == address(0)) {
            token = clone(callTemplate);
            ETHCallOptionToken(token).init(expiration, strike);
            calls[expiration][strike] = token;
        }

        emit OptionTokenCreated(token, true, expiration, strike);
        return ETHCallOptionToken(token);
    }

    function findOrCreatePut(uint128 expiration, uint128 strike) internal returns (ETHPutOptionToken) {
        require(expiration > now && expiration % 86400 - 43200 == 0 && strike % 5 ether == 0 && strike > 0 ether && strike < 100000 ether);
        address token = puts[expiration][strike];
        if (token == address(0)) {
            token = clone(putTemplate);
            ETHPutOptionToken(token).init(expiration, strike);
            usd.approve(token, uint256(-1));
            puts[expiration][strike] = token;
        }

        emit OptionTokenCreated(token, false, expiration, strike);
        return ETHPutOptionToken(token);
    }

    function getTokenName(bool isCall, uint256 expiration, uint256 strike) pure external returns (string memory) {
        return OptionTokenNamesake.name(isCall, expiration, strike);
    }

    function getTokenSymbol(bool isCall, uint256 expiration, uint256 strike) pure external returns (string memory) {
        return OptionTokenNamesake.symbol(isCall, expiration, strike);
    }
}