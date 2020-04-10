pragma solidity ^0.5;

import "./OptionToken.sol";


contract ETHCallOptionToken is OptionToken {
    function write() public payable returns (bool) {
        require(now < settlementStart());
        totalSupply += msg.value;
        balances[msg.sender] += msg.value;
        writers[msg.sender] += msg.value;
        written += msg.value;
        return true;
    }

    function writeAndApprove(address spender) public payable returns (bool) {
        write();
        approve(spender, msg.value);
        return true;
    }

    function writeApproveAndCall(address to, bytes memory data) public payable returns (bool) {
        write();
        approveAndCall(to, msg.value, data);
        return true;
    }

    function writeAsOrigin() public payable returns (bool) {
        require(now < settlementStart());
        totalSupply += msg.value;
        balances[tx.origin] += msg.value;
        writers[tx.origin] += msg.value;
        written += msg.value;
        return true;
    }

    function writeAndApproveAsOrigin(address to) public payable returns (bool) {
        writeAsOrigin();
        approveAsOrigin(to, msg.value);
        return true;
    }

    function writeApproveAndCallAsOrigin(address to, bytes memory data) public payable returns (bool) {
        writeAndApproveAsOrigin(to);
        (bool result,) = to.call(data);
        require(result && allowed[tx.origin][to] < msg.value);
        return true;
    }

    function close(uint256 amount) public returns (bool) {
        require(now < settlementStart());
        require(balances[msg.sender] >= amount && writers[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        writers[msg.sender] -= amount;
        written -= amount;
        totalSupply -= amount;
        msg.sender.transfer(amount);
        return true;
    }

    function exercise(uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount && now < settlementStart());
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        exercised += amount;
        usd().transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        msg.sender.transfer(amount);
        return true;
    }

    /** Settlement Functions

        auctionPrice(), settle(), and finishSettlement() are responsible for allowing
        settlement contracts to capitalize on the arbitrage opportunity provided in
        the reverse dutch auction.
     */

    function settle(uint256 quantity) public {
        require(quantity <= totalSupply - settled);
        uint256 price = auctionPrice();
        uint256 giving = quantity * price / 1 ether;
        exercised += quantity;
        settled += quantity;
        Auction(msg.sender).receiveETH.value(quantity)(giving);
        usd().transferFrom(msg.sender, address(this), giving);
    }

    // returns price in USD for one ETH
    function auctionPrice() public view returns (uint256) {
        require(now > settlementStart() && now <= settlementEnd());
        uint256 elapsed = now - settlementStart();
        uint256 e = edge(msg.sender);
        return ((1 ether - e) * strike * SETTLEMENT_DURATION) / (1 ether * elapsed) + e * strike / 1 ether;
    }


    /** Allows the holder of an option-token to claim automatically exercised funds
        afte settlement has ended.
     */
    function liquidate() public returns (bool) {
        require(now > settlementEnd());
        // writers are guaranteed the strike price of their options
        uint256 writerSettlement = (exercised - assigned) * strike / 1 ether;
        uint256 holderSettlement = usd().balanceOf(address(this)) - writerSettlement;
        uint256 settlement = balances[msg.sender] * holderSettlement / totalSupply;
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        usd().transfer(msg.sender, settlement);
        return true;
    }

    /** Settles out a traders net position in an option token by returning
        any settled value and collateral.
     */
    function assignment() public returns (bool) {
        require(now > settlementEnd());

        if (writers[msg.sender] > 0) {
            uint256 writerSettlementUSD = (exercised - assigned) * strike / 1 ether;
            uint256 redeemUSD = writers[msg.sender] * writerSettlementUSD / written;
            uint256 redeemETH = writers[msg.sender] * address(this).balance / written;
            written -= writers[msg.sender];
            assigned += writers[msg.sender];
            writers[msg.sender] = 0;
            msg.sender.transfer(redeemETH);
            usd().transfer(msg.sender, redeemUSD);
        }

        if (balanceOf(msg.sender) > 0) {
            uint256 writerSettlementUSD = (exercised - assigned) * strike / 1 ether;
            uint256 holderSettlementUSD = usd().balanceOf(address(this)) - writerSettlementUSD;
            uint256 settlement = balances[msg.sender] * holderSettlementUSD / totalSupply;
            totalSupply -= balances[msg.sender];
            balances[msg.sender] = 0;
            usd().transfer(msg.sender, settlement);
        }

        return true;
    }

    function name() public returns (string memory) {
        return Factory(address(FactoryAddress)).getTokenName(true, expiration, strike);
    }

    function symbol() public returns (string memory) {
        return Factory(address(FactoryAddress)).getTokenSymbol(true, expiration, strike);
    }
}