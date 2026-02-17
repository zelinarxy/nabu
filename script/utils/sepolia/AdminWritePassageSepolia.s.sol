// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "lib/forge-std/src/Script.sol";

import {Nabu} from "../../../src/Nabu.sol";
import {NABU} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
uint256 constant PASSAGE_ID = 1;
uint256 constant WORK_ID = 1;
// Don't remove the `unicode` prefix
string constant RAW_PASSAGE = unicode"In the beginning God created the heaven and the earth.";

contract AdminWritePassageSepolia is Script {
    Nabu public nabu;

    bytes passage = bytes(RAW_PASSAGE);

    function run() public {
        vm.startBroadcast();

        nabu = Nabu(NABU);
        nabu.adminAssignPassageContent({content: passage, passageId: PASSAGE_ID, workId: WORK_ID});

        vm.stopBroadcast();
    }
}
