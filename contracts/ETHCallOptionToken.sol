pragma solidity ^0.5;

import "./OptionToken.sol";


contract ETHCallOptionToken is OptionToken {
    function write() public payable returns (bool) {
        totalSupply += msg.value;
        balances[msg.sender] += msg.value;
        writers[msg.sender] += msg.value;
        written += msg.value;
        return true;
    }

    function writeApproveAndCall(address writer, address to, bytes memory data) public payable returns (bool) {
        totalSupply += msg.value;
        writers[writer] += msg.value;
        written += msg.value;
        uint256 allowanceWas = allowed[writer][to];
        allowed[writer][to] += msg.value;
        (bool result,) = to.call(data);
        require(result && allowed[writer][to] == allowanceWas);
        return true;
    }

    function close(uint256 amount) public returns (bool) {
        require(now < settlementStart());
        require(balances[msg.sender] >= amount && writers[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        writers[msg.sender] -= amount;
        written -= amount;
        msg.sender.transfer(amount);
        return true;
    }

    function exercise(uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount && now < settlementStart());
        balances[msg.sender] -= amount;
        totalSupply -= amount;
        usd.transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        msg.sender.transfer(amount);
        return true;
    }

    function liquidate(uint256 quantity) public {
        uint256 elapsed = settlementEnd() - now;
        uint256 price = strike * SETTLEMENT_DURATION / elapsed;
        require(now < settlementEnd() && now > settlementStart() && price >= strike);
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

    function settle() public returns (bool) {
        require(now > settlementEnd());
        uint256 writerSettlement = (liquidated - redeemed) * strike / 1 ether;
        uint256 holderSettlement = usd.balanceOf(address(this)) - writerSettlement;
        uint256 settlement = (balances[msg.sender] * 1 ether / totalSupply) * holderSettlement / 1 ether;
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        usd.transfer(msg.sender, settlement);
        return true;
    }

    function redeem() public returns (bool) {
        require(now > settlementEnd());
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