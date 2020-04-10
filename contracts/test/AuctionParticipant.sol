pragma solidity ^0.5;

import "../ETHCallOptionToken.sol";
import "../ETHPutOptionToken.sol";


/**
    This is an example of an Auction participant smart contract.

    It does no authorization/authentication of any other contracts,
    but it does illustrate the basic concepts involved in settlement.
 */

contract AuctionParticipant {
    function settleCall(address token, uint256 quantity) public {
        ETHCallOptionToken callToken = ETHCallOptionToken(token);
        _assumeDSFTokenBalance(callToken.dsf());
        callToken.settle(quantity);
        _returnDSFTokenBalance(callToken.dsf());
    }

    function settlePut(address token) public payable {
        ETHPutOptionToken putToken = ETHPutOptionToken(token);
        _assumeDSFTokenBalance(putToken.dsf());
        putToken.settle(msg.value);
        _returnDSFTokenBalance(putToken.dsf());
    }

    function receiveETH(uint256 expectingUSDAmount) public payable returns (bool) {
        ETHCallOptionToken callToken = ETHCallOptionToken(msg.sender);
        ERC20 usdToken = callToken.usd();
        usdToken.approve(address(callToken), expectingUSDAmount);
        return true;
    }

    function receiveUSD(uint256 expectingETHAmount) public returns (bool) {
        ETHPutOptionToken putToken = ETHPutOptionToken(msg.sender);
        uint256 allowed = putToken.usd().allowed(address(putToken), address(this));
        putToken.usd().transferFrom(address(putToken), address(this), allowed);
        putToken.finalizeSettlement.value(expectingETHAmount)();
        return true;
    }

    event Finalized();

    function finalizedCallback() public {
        emit Finalized();
    }

    function _assumeDSFTokenBalance(ERC20 dsf) internal {
        dsf.transferFrom(msg.sender, address(this), dsf.allowed(msg.sender, address(this)));
    }

    function _returnDSFTokenBalance(ERC20 dsf) internal {
        dsf.transfer(msg.sender, dsf.balanceOf(address(this)));
    }
}