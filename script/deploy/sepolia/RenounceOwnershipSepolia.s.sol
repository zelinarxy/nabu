// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Ashurbanipal} from "../../../src/Ashurbanipal.sol";
import {Nabu} from "../../../src/Nabu.sol";
import {ASHURBANIPAL, NABU} from "./constants/DeployedAddresses.sol";

contract RenounceOwnershipSepolia is Script {
    Ashurbanipal public ashurbanipal;
    Nabu public nabu;

    function run() public {
        vm.startBroadcast();

        ashurbanipal = Ashurbanipal(ASHURBANIPAL);
        ashurbanipal.renounceOwnership();

        nabu = Nabu(NABU);
        nabu.renounceOwnership();

        vm.stopBroadcast();
    }
}
