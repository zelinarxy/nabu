// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Humbaba} from "../../../src/Humbaba.sol";
import {HUMBABA} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
address constant TO = address(0);

contract AdminMintHumbabaSepolia is Script {
    Humbaba public humbaba;

    function run() public {
        vm.startBroadcast();

        humbaba = Humbaba(HUMBABA);
        humbaba.adminMintTo({to: TO});

        vm.stopBroadcast();
    }
}
