// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

// Update as needed
address payable constant TO = payable(address(0));
uint256 constant AMOUNT = 0.1 ether;

contract SendEthSepolia is Script {
    function run() public {
        vm.startBroadcast();
        TO.transfer(AMOUNT);
        vm.stopBroadcast();
    }
}
