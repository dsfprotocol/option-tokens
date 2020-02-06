pragma solidity ^0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/OptionTokenFactory.sol";
import "../contracts/ETHCallOptionToken.sol";


contract ETHCallOptionTokenTest {
    uint public initialBalance = 100 ether;
    ETHCallOptionToken public testToken;

    function beforeAll() public {
        OptionTokenFactory factory = OptionTokenFactory(DeployedAddresses.OptionTokenFactory());
        factory.createToken();
    }

    function optionTokenWasCloned(address token) public returns (bool) {
        testToken = ETHCallOptionToken(testToken);

        ETHCallOptionToken(token).init(
            "TEST OPTION TOKEN",
            "TEST",
            now + 28 days,
            200 ether
        );

        return true;
    }
}