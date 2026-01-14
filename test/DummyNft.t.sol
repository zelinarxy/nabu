// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/DummyNft.sol";

// TODO: mismatch messages on assertEq
contract DummyNftTest is Test {
    DummyNft public dummyNft;
    address alice = makeAddr("Alice");

    function setUp() public {
        dummyNft = new DummyNft();
    }

    function testName() public {
        assertEq(dummyNft.name(), "DummyNft");
    }

    function testSymbol() public {
        assertEq(dummyNft.symbol(), "DUMMY");
    }

    function testMintTo() public {
        dummyNft.mintTo(address(alice));
        assertEq(dummyNft.balanceOf(address(alice)), 1);
    }

    function testTokenURI() public {
        dummyNft.mintTo(address(alice));
        assertEq(dummyNft.tokenURI(1), "");
    }
}
