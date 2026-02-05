// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Humbaba} from "../../../src/Humbaba.sol";

string constant BASE_URI = "";

contract DeployHumbabaSepolia is Script {
    Humbaba public humbaba;

    function run() public {
        vm.startBroadcast();
        humbaba = new Humbaba(BASE_URI);
        vm.stopBroadcast();
    }
}
