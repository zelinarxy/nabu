// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Nabu} from "../../../src/Nabu.sol";
import {ASHURBANIPAL, NABU} from "./constants/DeployedAddresses.sol";

contract UpdateAshurbanipalAddressSepolia is Script {
    Nabu public nabu;

    function run() public {
        vm.startBroadcast();

        nabu = Nabu(NABU);
        nabu.updateAshurbanipal(ASHURBANIPAL);

        vm.stopBroadcast();
    }
}
