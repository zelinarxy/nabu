// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Enkidu} from "../../../src/Enkidu.sol";
import {ENKIDU} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
uint256 constant PRICE = 0.001 ether;
uint256 constant WORK_ID = 1;

contract ConfigureEnkiduMintSepolia is Script {
    Enkidu public enkidu;

    function run() public {
        vm.startBroadcast();
        enkidu = Enkidu(ENKIDU);

        enkidu.updatePrice({id: WORK_ID, price: PRICE});

        enkidu.updateActive({id: WORK_ID, isActive: true});

        vm.stopBroadcast();
    }
}
