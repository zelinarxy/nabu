// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Enkidu, WhitelistedToken} from "../../../src/Enkidu.sol";
import {ENKIDU} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
uint256 constant COUNT = 1;
address constant TO = address(0);
uint256 constant WORK_ID = 1;

contract FreeMintEnkiduSepolia is Script {
    Enkidu public enkidu;

    function run() public {
        vm.startBroadcast();
        enkidu = Enkidu(ENKIDU);

        enkidu.mint({id: WORK_ID, count: COUNT, to: TO, whitelistedToken: WhitelistedToken.Humbaba});

        vm.stopBroadcast();
    }
}
