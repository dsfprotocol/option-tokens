pragma solidity ^0.5;

library ETHCallOptionTokenAddress {}


contract ETHCallOptionTokenProxy {
    function () external payable {
        //solium-disable-next-line security/no-inline-assembly
        address tokenLib = address(ETHCallOptionTokenAddress);
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            let result := delegatecall(gas, tokenLib, ptr, calldatasize, 0, 0)
            let size := returndatasize
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}