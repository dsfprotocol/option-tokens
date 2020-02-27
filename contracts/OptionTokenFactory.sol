pragma solidity ^0.5;

import "./Cloner.sol";
import "./ETHCallOptionToken.sol";
import "./ETHPutOptionToken.sol";
import "./ETHCallOptionTokenProxy.sol";
import "./ETHPutOptionTokenProxy.sol";


contract OptionTokenFactory is Cloner {
    mapping(uint128 => mapping(uint128 => address)) public calls;
    mapping(uint128 => mapping(uint128 => address)) public puts;

    address public callTemplate;
    address public putTemplate;

    event OptionTokenCreated(address token, bool isCall, uint128 expiration, uint128 strike);

    constructor() public {
        callTemplate = address(new ETHCallOptionTokenProxy());
        putTemplate = address(new ETHPutOptionTokenProxy());
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
        return address(findOrCreateCall(expiration, strike));
    }

    function writePut(uint128 expiration, uint128 strike) public returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeAsOrigin();
    }

    function writePut(uint128 expiration, uint128 strike, address approve) public returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeAndApproveAsOrigin(approve);
    }

    function writePut(uint128 expiration, uint128 strike, address approve, bytes memory data) public returns (address) {
        ETHCallOptionToken token = findOrCreateCall(expiration, strike);
        token.writeApproveAndCallAsOrigin(approve, data);
    }

    function findOrCreateCall(uint128 expiration, uint128 strike) internal returns (ETHCallOptionToken) {
        require(expiration > now && expiration % 86400 - 43200 == 0 && strike % 5 ether == 0 && strike < 100000 ether);
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
        require(expiration > now && expiration % 86400 - 43200 == 0 && strike % 5 ether == 0 && strike < 100000 ether);
        address token = calls[expiration][strike];
        if (token == address(0)) {
            token = clone(putTemplate);
            ETHPutOptionToken(token).init(expiration, strike);
            calls[expiration][strike] = token;
        }

        emit OptionTokenCreated(token, false, expiration, strike);
        return ETHPutOptionToken(token);
    }

    function getTokenName(bool isCall, uint128 expiration, uint128 strike) pure external returns (string memory) {

    }

    function getTokenSymbol(bool isCall, uint128 expiration, uint128 strike) pure external returns (string memory) {

    }
}