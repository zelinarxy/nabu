// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibZip} from "lib/solady/src/utils/LibZip.sol";
import {LibString} from "lib/solady/src/utils/LibString.sol";
import {SSTORE2} from "lib/solady/src/utils/SSTORE2.sol";
import {Script, console} from "lib/forge-std/src/Script.sol";

import {Nabu, Passage} from "../../../src/Nabu.sol";
import {ENKIDU, NABU} from "../../constants/sepolia/DeployedAddressesSepolia.sol";

// Update as needed
uint256 constant PASSAGE_ID = 1;
uint256 constant WORK_ID = 1;

contract GetPassageSepolia is Script {
    Nabu public nabu;

    function run() public {
        nabu = Nabu(NABU);

        Passage memory passage = nabu.getPassage({passageId: PASSAGE_ID, workId: WORK_ID});

        bytes memory rawContent = SSTORE2.read(passage.content);

        console.log("raw content:", string(rawContent));

        console.log("content:", string(LibZip.flzDecompress(rawContent)));

        console.log("byZero:", passage.byZero);
        console.log("byOne:", passage.byOne);
        console.log("byTwo:", passage.byTwo);
        console.log("at:", LibString.toString(passage.at));
    }
}
