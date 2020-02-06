pragma solidity ^0.5;


contract Math {
    function ln(uint x) pure public returns (uint log) {
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