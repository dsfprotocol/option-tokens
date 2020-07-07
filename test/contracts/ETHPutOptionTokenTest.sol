pragma solidity ^0.5;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/OptionTokenFactory.sol";
import "../../contracts/ETHPutOptionToken.sol";
import "default-balance-token/DefaultBalanceToken.sol";


contract ETHPutOptionTokenTest {
    uint public initialBalance = 10 ether;
    ETHPutOptionToken public token;
    DefaultBalanceToken usd;
    address self;

    uint256 expiration = now + 28 days;
    uint256 constant STRIKE = 200 ether;

    function() external payable {}

    function beforeAll() public {
        expiration = now + 28 days;
        self = address(this);
        OptionTokenFactory factory = OptionTokenFactory(DeployedAddresses.OptionTokenFactory());
        usd = DefaultBalanceToken(0x4F678ceBFe01CF0A111600b3d0AFC27885aA578d);
        factory.createPutOptionToken();
    }

    function optionTokenWasCloned(address _token) public returns (bool) {
        token = ETHPutOptionToken(_token);

        ETHPutOptionToken(token).init(
            "TEST OPTION TOKEN",
            "TEST",
            expiration,
            STRIKE
        );

        return true;
    }

    function testWriteOptionToken() public {
        usd.approve(address(token), STRIKE);
        token.write(1 ether);

        Assert.equal(token.balanceOf(self), 1 ether, "Balance of 1 option token was not recorded");
        Assert.equal(token.writers(self),   1 ether, "Balance as writer of option token was not recorded");
    }

    function testExerciseOptionToken() public {
        Assert.equal(usd.balanceOf(self), 1000000 ether, "Default balance is not 1M tokens.");
        Assert.equal(usd.balanceOf(self), 0, "Assert that approval is correct.");
        Assert.fail("Not actually failing");
        token.exercise.value(1 ether)();
        Assert.equal(usd.allowed(self, address(token)), 0, "Approvals not deducted correctly.");
        Assert.equal(usd.balanceOf(self), 1000000 ether - STRIKE, "Strike price was not paid correctly.");
        // Assert.equal(self.balance - previousEther, 1 ether, "Ether from exercise was not received.");
    }

    function testCloseOptionToken() public {
        usd.approve(address(token), STRIKE);
        token.write(1 ether);
        // assert token was written
        token.close(1 ether);
    }

    function testTransferOptionToken() public {
        usd.approve(address(token), 0.1 ether * STRIKE / 1 ether);
        token.write(0.1 ether);
        token.transfer(address(0), 0.1 ether);
    }
}