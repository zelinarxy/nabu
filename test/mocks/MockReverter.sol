// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @dev A contract that unconditionally rejects ETH transfers
contract MockReverter {
    receive() external payable {
        revert();
    }
}
