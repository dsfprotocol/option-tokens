pragma solidity ^0.5;

import "./DateTime.sol";


library OptionTokenNamesake {
    function name(bool isCall, uint256 expiration, uint256 strike) public pure returns (string memory) {
        (, uint month, uint date) = DateTime.timestampToDate(expiration);
        string memory monthName = monthName(month - 1);
        return strConcat(
            strConcat(monthName, " ", uint2str(date), " ", uint2str(strike / 1 ether)),
        "-", isCall ? "CALL" : "PUT", "", "");
    }

    function symbol(bool isCall, uint256 expiration, uint256 strike) public pure returns (string memory) {
        (, uint month, uint date) = DateTime.timestampToDate(expiration);

        return strConcat(uint2str(month), "/", uint2str(date), " ", strConcat(
            uint2str(strike / 1 ether), "-", isCall ? "C" : "P", "", ""
        ));
    }

    function monthName(uint256 month) public pure returns (string memory) {
        string[12] memory MONTH_NAMES = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        return MONTH_NAMES[month];
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory _concatenatedString) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        uint i = 0;
        for (i = 0; i < _ba.length; i++) {
            babcde[k++] = _ba[i];
        }
        for (i = 0; i < _bb.length; i++) {
            babcde[k++] = _bb[i];
        }
        for (i = 0; i < _bc.length; i++) {
            babcde[k++] = _bc[i];
        }
        for (i = 0; i < _bd.length; i++) {
            babcde[k++] = _bd[i];
        }
        for (i = 0; i < _be.length; i++) {
            babcde[k++] = _be[i];
        }
        return string(babcde);
    }
}