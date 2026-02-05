// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Nabu} from "../../../src/Nabu.sol";

contract DeployNabuSepolia is Script {
    Nabu public nabu;

    function run() public {
        vm.startBroadcast();
        nabu = new Nabu();
        vm.stopBroadcast();
    }
}
