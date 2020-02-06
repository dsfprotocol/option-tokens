pragma solidity ^0.5;

import "./Math.sol";
import "./ERC20.sol";
import "./LiquidatorInterface.sol";


contract ETHCallOptionToken is ERC20, Math {
    bool public initialized = false;
    uint256 public expiration;
    uint256 public strike;

    mapping(address => uint256) writers;

    uint256 public liquidated;
    uint256 public written;
    uint256 public redeemed;

    ERC20 public usd = ERC20(0x27299fb009daF9B5a4eD757364ffFC4F0664d2c8);
    ERC20 public dsf = ERC20(0xe86079F6AF02280b73933BA2C287B5733029feCc);

    // called by Factory in same transaction as deploy
    function init(
        string memory _name,
        string memory _symbol,
        uint256 _expiration,
        uint256 _strike
    ) public returns (bool) {
        require(initialized == false);
        name = string(_name);
        symbol = string(_symbol);
        expiration = _expiration;
        strike = _strike;
        initialized = true;
        return true;
    }

    function write() public payable returns (bool) {
        totalSupply += msg.value;
        balances[msg.sender] += msg.value;
        writers[msg.sender] += msg.value;
        written += msg.value;
        return true;
    }

    function writeApproveAndCall(address to, bytes memory data) public payable returns (bool) {
        totalSupply += msg.value;
        writers[msg.sender] += msg.value;
        written += msg.value;
        allowed[msg.sender][to] = msg.value;
        (bool result,) = to.call(data);
        require(result);
        return true;
    }

    function close(uint256 amount) public returns (bool) {
        require(now < expiration);
        require(balances[msg.sender] >= amount && writers[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        writers[msg.sender] -= amount;
        written -= amount;
        msg.sender.transfer(amount);
    }

    function exercise(uint256 amount) public {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        usd.transferFrom(msg.sender, address(this), amount * strike / 1 ether);
        msg.sender.transfer(amount);
    }

    function liquidate(uint256 quantity) public {
        uint256 AUCTION_DURATION = 12 hours;
        uint256 start = expiration - AUCTION_DURATION;
        uint256 elapsed = expiration - start;
        uint256 price = strike * AUCTION_DURATION / elapsed;

        require(now < expiration && now > start && price >= strike);

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
        require(now > expiration);
        uint256 writerSettlement = (liquidated - redeemed) * strike / 1 ether;
        uint256 holderSettlement = usd.balanceOf(address(this)) - writerSettlement;
        uint256 settlement = (balances[msg.sender] * 1 ether / totalSupply) * holderSettlement / 1 ether;
        totalSupply -= balances[msg.sender];
        balances[msg.sender] = 0;
        usd.transfer(msg.sender, settlement);
        return true;
    }

    function redeem() public returns (bool) {
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