pragma solidity ^0.5;

import "./OptionToken.sol";


contract ETHPutOptionToken is OptionToken {

    // used in settlement when USD is sent and contract expects ETH in return.
    mapping(address => uint256) ethOwed;

    function write(uint256 amount) public returns (bool) {
        require(now < settlementStart());
        usd().transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        totalSupply += amount;
        balances[msg.sender] += amount;
        writers[msg.sender] += amount;
        written += amount;
        return true;
    }

    function writeAndApprove(uint256 amount, address spender) public payable returns (bool) {
        write(amount);
        approve(spender, msg.value);
    }

    function writeApproveAndCall(uint256 amount, address to, bytes memory data) public returns (bool) {
        write(amount);
        approveAndCall(to, amount, data);
        return true;
    }

    function close(uint256 amount) public returns (bool) {
        require(now < settlementStart());
        require(balances[msg.sender] >= amount && writers[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        writers[msg.sender] -= amount;
        written -= amount;
        totalSupply -= amount;
        usd().transfer(msg.sender, amount);
        return true;
    }

    function exercise() public payable returns (bool) {
        require(balances[msg.sender] >= msg.value && now < settlementStart());
        balances[msg.sender] -= msg.value;
        totalSupply -= msg.value;
        exercised += msg.value;
        usd().transfer(msg.sender, msg.value * strike / 1 ether);
        return true;
    }

    function assignment() public returns (bool) {
        require(now > settlementEnd());

        if (writers[msg.sender] > 0) {
            uint256 writerSettlementUSD = (written - exercised) * strike / 1 ether;
            uint256 redeemUSD = writers[msg.sender] * writerSettlementUSD / written;
            uint256 redeemETH = writers[msg.sender] * address(this).balance / written;
            written -= writers[msg.sender];
            assigned += writers[msg.sender];
            writers[msg.sender] = 0;
            msg.sender.transfer(redeemETH);
            usd().transfer(msg.sender, redeemUSD);
        }

        if (balanceOf(msg.sender) > 0) {
            uint256 writerSettlementUSD = (written - exercised) * strike / 1 ether;
            uint256 holderSettlement = usd().balanceOf(address(this)) - writerSettlementUSD;
            uint256 settlement = balances[msg.sender] * holderSettlement / totalSupply;
            totalSupply -= balances[msg.sender];
            balances[msg.sender] = 0;
            usd().transfer(msg.sender, settlement);
        }

        return true;
    }

    /** Settlement Functions

        auctionPrice(), settle(), and finishSettlement() are responsible for allowing
        settlement contracts to capitalize on the arbitrage opportunity provided in
        the reverse dutch auction.
     */

    function settle(uint256 quantity) public {
        uint256 price = auctionPrice();
        require(quantity <= totalSupply - settled);
        uint256 usdAmount = quantity * 1 ether / price;
        ethOwed[msg.sender] = quantity;
        usd().approve(msg.sender, usdAmount);
        Auction(msg.sender).receiveUSD(quantity);
        require(ethOwed[msg.sender] == 0 && usd().allowed(address(this), msg.sender) == 0 && price >= (1 ether * 1 ether) / strike);
        exercised += quantity;
        settled += quantity;
    }

    function finalizeSettlement() public payable {
        require(msg.value == ethOwed[msg.sender]);
        ethOwed[msg.sender] = 0;
    }

    // returns the price in ETH for one USD.
    function auctionPrice() public view returns (uint256) {
        require(now > settlementStart() && now <= settlementEnd());
        uint256 elapsed = now - settlementStart();
        uint256 e = edge(msg.sender);
        return (1 ether * (1 ether - e) * SETTLEMENT_DURATION) / (strike * elapsed) + e * 1 ether / strike;
    }


    /** Name & Symbol Functions

        These functions have no technical influence on the mechanics of an option token.
        They serve to fill the user interface "name" and "symbol" fields with sensible
        information about the option token.
     */

    function name() public returns (string memory) {
        return Factory(address(FactoryAddress)).getTokenName(false, expiration, strike);
    }

    function symbol() public returns (string memory) {
        return Factory(address(FactoryAddress)).getTokenSymbol(false, expiration, strike);
    }
}