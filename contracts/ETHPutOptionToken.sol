pragma solidity ^0.5;

import "./OptionToken.sol";


contract ETHPutOptionToken is OptionToken {
    function write(uint256 amount) public returns (bool) {
        usd.transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        totalSupply += amount;
        balances[msg.sender] += amount;
        writers[msg.sender] += amount;
        written += amount;
        return true;
    }

    function writeApproveAndCall(address to, uint256 amount, bytes memory data) public returns (bool) {
        usd.transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        totalSupply += amount;
        balances[msg.sender] += amount;
        writers[msg.sender] += amount;
        written += amount;
        (bool result,) = to.call(data);
        require(result);
        return true;
    }

    function close(uint256 amount) public returns (bool) {
        require(now < settlementStart());
        require(balances[msg.sender] >= amount && writers[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        writers[msg.sender] -= amount;
        written -= amount;
        usd.transfer(msg.sender, amount);
        return true;
    }

    function exercise() public payable returns (bool) {
        require(balances[msg.sender] >= msg.value && now < settlementStart());
        balances[msg.sender] -= msg.value;
        totalSupply -= msg.value;
        usd.transfer(msg.sender, msg.value * strike / 1 ether);
        return true;
    }

    function settle(uint256 quantity) public {
        uint256 elapsed = now - settlementStart();
        uint256 price = strike * SETTLEMENT_DURATION / elapsed;

        require(now > settlementStart() && now < settlementEnd() && price >= strike);

        uint256 giving = quantity * price / 1 ether;

        if (usd.balanceOf(msg.sender) >= giving) {
            usd.transferFrom(msg.sender, address(this), giving);
            msg.sender.transfer(quantity);
        } else {
            LiquidatorInterface(msg.sender).receiveETH.value(quantity)();
            usd.transferFrom(msg.sender, address(this), giving);
        }

        liquidated += quantity;
    }

    function liquidate() public returns (bool) {
        require(now > expiration);
        uint256 writerSettlement = (liquidated - redeemed) * strike / 1 ether;
        uint256 holderSettlement = usd.balanceOf(address(this)) - writerSettlement;
        uint256 settlement = (balances[msg.sender] * 1 ether / totalSupply) * holderSettlement / 1 ether;
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        usd.transfer(msg.sender, settlement);
        return true;
    }

    function assign() public returns (bool) {
        require(now > expiration);
        uint256 writerSettlementUSD = (liquidated - redeemed) * strike / 1 ether;
        uint256 ratio = writers[msg.sender] * 1 ether / written;
        uint256 redeemUSD = ratio * writerSettlementUSD / 1 ether;
        uint256 redeemETH = ratio * address(this).balance / 1 ether;
        written -= writers[msg.sender];
        redeemed += writers[msg.sender];
        writers[msg.sender] = 0;
        msg.sender.transfer(redeemETH);
        usd.transfer(msg.sender, redeemUSD);
        return true;
    }
}