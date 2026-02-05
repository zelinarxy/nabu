// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Enkidu} from "../../../src/Enkidu.sol";
import {ASHURBANIPAL, HUMBABA} from "./constants/DeployedAddresses.sol";

contract DeployEnkiduSepolia is Script {
    Enkidu public enkidu;

    function run() public {
        vm.startBroadcast();
        enkidu = new Enkidu(ASHURBANIPAL, HUMBABA);
        vm.stopBroadcast();
    }
}
