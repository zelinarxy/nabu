// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Nabu} from "../../../src/Nabu.sol";
import {ENKIDU, NABU} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
string constant AUTHOR = "";
string constant METADATA = "";
string constant TITLE = "The King James Version of the Bible";
uint256 constant TOTAL_PASSAGES_COUNT = 31_102;
string constant URI = "";
uint256 constant SUPPLY = 1_000;

contract CreateWorkSepolia is Script {
    Nabu public nabu;

    function run() public {
        vm.startBroadcast();

        nabu = Nabu(NABU);
        nabu.createWork({
            author: AUTHOR,
            metadata: METADATA,
            title: TITLE,
            totalPassagesCount: TOTAL_PASSAGES_COUNT,
            uri: URI,
            supply: SUPPLY,
            mintTo: ENKIDU
        });

        vm.stopBroadcast();
    }
}
