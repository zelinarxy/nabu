// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/TestNft.sol";

// TODO: mismatch messages on assertEq
contract TestNftTest is Test {
    TestNft public testNft;
    address alice = makeAddr("Alice");

    function setUp() public {
        testNft = new TestNft();
    }

    function testName() public {
        assertEq(testNft.name(), "TestNft");
    }

    function testSymbol() public {
        assertEq(testNft.symbol(), "TEST");
    }

    function testMintTo() public {
        testNft.mintTo(address(alice));
        assertEq(testNft.balanceOf(address(alice)), 1);
    }

    function testTokenURI() public {
        testNft.mintTo(address(alice));
        assertEq(testNft.tokenURI(1), "");
    }
}
