// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Timecheck {
        // A view function. The `block.timestamp` will return the timestamp of the best block
    // (the block at the tip of the blockchain)
    function getCurrentContractTimeStamp() public view returns(uint256) {
        return block.timestamp;
    }
}