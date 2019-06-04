pragma solidity ^0.5;

import "./ERC20.sol";
import "./OptionToken.sol";
import "./VariableSupplyToken.sol";
import "./DSFProtocolTypes.sol";
import "./BidderInterface.sol";


contract DSFProtocol is DSFProtocolTypes {
    
    string public constant VERSION = "1.0";
    
    ERC20 public usdERC20;
    ERC20 public protocolToken;

    struct OptionSeries {
        uint expiration;
        Flavor flavor;
        uint strike;
    }

    uint public constant DURATION = 12 hours;
    uint public constant HALF_DURATION = DURATION / 2;

    mapping(address => uint) public openInterest;
    mapping(address => uint) public earlyExercised;
    mapping(address => uint) public totalInterest;
    mapping(address => mapping(address => uint)) public writers;
    mapping(address => OptionSeries) public seriesInfo;
    mapping(address => uint) public holdersSettlement;

    mapping(address => uint) public expectValue;
    bool isAuction;
    
    
    uint public constant PREFERENCE_MAX = 0.037 ether;

    constructor(address _token, address _usd) public {
        protocolToken = ERC20(_token);
        usdERC20 = ERC20(_usd);
    }

    function() external payable {
        revert();
    }

    event OptionTokenCreated(address token);
    // Note, this just creates an option token, it doesn't guarantee
    // settlement of that token. For guaranteed settlement see the DSFProtocolProxy contract(s)
    function issue(string memory name, string memory symbol, uint expiration, Flavor flavor, uint strike) public returns (address) {
        address series = address(new OptionToken(name, symbol));
        seriesInfo[series] = OptionSeries(expiration, flavor, strike);
        emit OptionTokenCreated(series);
        return series;
    }

    function open(address _series, uint amount) public payable returns (bool) {
        OptionSeries memory series = seriesInfo[_series];
        require(now < series.expiration);

        if (series.flavor == Flavor.Call) {
            require(msg.value == amount);
        } else {
            require(msg.value == 0);
            uint escrow = amount * series.strike;
            require(escrow / amount == series.strike);
            escrow /= 1 ether;
            require(usdERC20.transferFrom(msg.sender, address(this), escrow));
        }
        
        VariableSupplyToken(_series).grant(msg.sender, amount);

        openInterest[_series] += amount;
        totalInterest[_series] += amount;
        writers[_series][msg.sender] += amount;

        return true;
    }

    function close(address _series, uint amount) public returns (bool) {
        OptionSeries memory series = seriesInfo[_series];

        require(now < series.expiration);
        require(openInterest[_series] >= amount);
        VariableSupplyToken(_series).burn(msg.sender, amount);

        require(writers[_series][msg.sender] >= amount);
        writers[_series][msg.sender] -= amount;
        openInterest[_series] -= amount;
        totalInterest[_series] -= amount;
        
        if (series.flavor == Flavor.Call) {
            msg.sender.transfer(amount);
        } else {
            usdERC20.transfer(msg.sender, amount * series.strike / 1 ether);
        }
        return true;
    }
    
    function exercise(address _series, uint amount) public payable {
        OptionSeries memory series = seriesInfo[_series];

        require(now < series.expiration);
        require(openInterest[_series] >= amount);
        VariableSupplyToken(_series).burn(msg.sender, amount);

        uint usd = amount * series.strike;
        require(usd / amount == series.strike);
        usd /= 1 ether;

        openInterest[_series] -= amount;
        earlyExercised[_series] += amount;

        if (series.flavor == Flavor.Call) {
            msg.sender.transfer(amount);
            require(msg.value == 0);
            usdERC20.transferFrom(msg.sender, address(this), usd);
        } else {
            require(msg.value == amount);
            usdERC20.transfer(msg.sender, usd);
        }
    }
    
    function receive() public payable returns (bool) {
        require(expectValue[msg.sender] == msg.value);
        expectValue[msg.sender] = 0;
        return true;
    }

    function bid(address _series, uint amount) public payable returns (bool) {

        require(isAuction == false);
        isAuction = true;

        OptionSeries memory series = seriesInfo[_series];

        uint start = series.expiration;
        require(now > start);
        require(now < start + DURATION);

        uint elapsed = now - start;

        // amount is upper-bounded to open interest of series
        amount = _min(amount, openInterest[_series]);

        openInterest[_series] -= amount;

        uint offer;
        uint givGet;
        uint discountRate = discount(msg.sender);
        
        BidderInterface bidder = BidderInterface(msg.sender);
        
        if (series.flavor == Flavor.Call) {
            require(msg.value == 0);

            offer = callAuctionUSDPrice(series.strike, elapsed, discountRate);
            givGet = offer * amount / 1 ether;
            
            holdersSettlement[_series] += givGet - amount * series.strike / 1 ether;

            bool hasFunds = usdERC20.balanceOf(msg.sender) >= givGet && usdERC20.allowance(msg.sender, address(this)) >= givGet;

            if (hasFunds) {
                msg.sender.transfer(amount);
            } else {
                bidder.receiveETH(_series, amount);
            }

            require(usdERC20.transferFrom(msg.sender, address(this), givGet));
        } else {
            // offer represents the amount the sender will sell eth for in USD
            offer = putAuctionUSDPrice(series.strike, elapsed, discountRate);
            
            // the amount in USD the sender will receive
            givGet = amount * offer / 1 ether;

            holdersSettlement[_series] += amount * series.strike / 1 ether - givGet;
            usdERC20.transfer(msg.sender, givGet);

            if (msg.value == 0) {
                require(expectValue[msg.sender] == 0);
                expectValue[msg.sender] = amount;
                
                bidder.receiveUSD(_series, givGet);
                require(expectValue[msg.sender] == 0);
            } else {
                require(msg.value >= amount);
                msg.sender.transfer(msg.value - amount);
            }
        }

        isAuction = false;
        return true;
    }
    
    function putAuctionUSDPrice(uint strike, uint elapsed, uint discountRate) public pure returns (uint) {
        uint price = elapsed * strike * 1 ether / (DURATION * discountRate);
        return _min(price, strike);
    }
    
    function callAuctionUSDPrice(uint strike, uint elapsed, uint discountRate) public pure returns (uint) {
        uint price = strike * DURATION / elapsed;
        return _max(
            price * discountRate / 1 ether,
            strike
        );
    }

    function redeem(address _series) public returns (uint eth, uint usd) {
        OptionSeries memory series = seriesInfo[_series];

        require(now > series.expiration + DURATION);

        uint unsettledPercent = openInterest[_series] * 1 ether / totalInterest[_series];
        uint exercisedPercent = (totalInterest[_series] - openInterest[_series]) * 1 ether / totalInterest[_series];
        uint owed;

        if (series.flavor == Flavor.Call) {
            eth = writers[_series][msg.sender] * unsettledPercent / 1 ether;

            if (eth > 0) {
                msg.sender.transfer(owed);
            }

            usd = writers[_series][msg.sender] * exercisedPercent / 1 ether;
            usd = usd * series.strike / 1 ether;
            if (usd > 0) {
                usdERC20.transfer(msg.sender, owed);
            }
        } else {
            usd = writers[_series][msg.sender] * unsettledPercent / 1 ether;
            usd = usd * series.strike / 1 ether;
            if (usd > 0) {
                usdERC20.transfer(msg.sender, usd);
            }

            eth = writers[_series][msg.sender] * exercisedPercent / 1 ether;
            if (eth > 0) {
                msg.sender.transfer(eth);
            }
        }

        writers[_series][msg.sender] = 0;
        return (eth, usd);
    }

    function settle(address _series) public returns (uint usd) {
        OptionSeries memory series = seriesInfo[_series];
        require(now > series.expiration + DURATION);

        uint bal = ERC20(_series).balanceOf(msg.sender);
        VariableSupplyToken(_series).burn(msg.sender, bal);

        uint percent = bal * 1 ether / (totalInterest[_series] - earlyExercised[_series]);
        uint usd = holdersSettlement[_series] * percent / 1 ether;
        usdERC20.transfer(msg.sender, usd);
        return usd;
    }
    
    // map preference to a discount factor between 0.95 and 1
    function discount(address from) public view returns (uint) {
        return (100 ether - _unsLn(preference(from) * 139 + 1 ether)) / 100;
    }
    
    // map the quantity between 0 and 3.7% of DSF token supply the user owns
    // to between 0 and 1
    function preference(address from) public view returns (uint) {
        uint percent = _min(
            protocolToken.balanceOf(from) * 1 ether / protocolToken.totalSupply(),
            PREFERENCE_MAX
        );
        
        uint normalized = percent * 1 ether / PREFERENCE_MAX;
        return normalized;
    }

    function _min(uint a, uint b) pure public returns (uint) {
        if (a > b)
            return b;
        return a;
    }

    function _max(uint a, uint b) pure public returns (uint) {
        if (a > b)
            return a;
        return b;
    }
    
    function _unsLn(uint x) pure public returns (uint log) {
        log = 0;
        
        // not a true ln function, we can't represent the negatives
        if (x < 1 ether)
            return 0;

        while (x >= 1.5 ether) {
            log += 0.405465 ether;
            x = x * 2 / 3;
        }
        
        x = x - 1 ether;
        uint y = x;
        uint i = 1;

        while (i < 10) {
            log += (y / i);
            i = i + 1;
            y = y * x / 1 ether;
            log -= (y / i);
            i = i + 1;
            y = y * x / 1 ether;
        }
         
        return(log);
    }
}