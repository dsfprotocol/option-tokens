pragma solidity ^0.5;


contract Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b)
            return a;
        return b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b)
            return a;
        return b;
    }
}