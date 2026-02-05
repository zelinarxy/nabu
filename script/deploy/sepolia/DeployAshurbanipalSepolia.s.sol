// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Ashurbanipal} from "../../../src/Ashurbanipal.sol";
import {NABU} from "./constants/DeployedAddresses.sol";

contract DeployAshurbanipalSepolia is Script {
    Ashurbanipal public ashurbanipal;

    function run() public {
        vm.startBroadcast();
        ashurbanipal = new Ashurbanipal(NABU);
        vm.stopBroadcast();
    }
}
