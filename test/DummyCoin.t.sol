// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/DummyCoin.sol";

// TODO: mismatch messages on assertEq
contract DummyCoinTest is Test {
    DummyCoin public dummyCoin;
    address alice = makeAddr("Alice");

    function setUp() public {
        dummyCoin = new DummyCoin();
    }

    function testName() public {
        assertEq(dummyCoin.name(), "DummyCoin");
    }

    function testSymbol() public {
        assertEq(dummyCoin.symbol(), "COIN");
    }

    function testMintTo() public {
        dummyCoin.mintTo(address(alice));
        assertEq(dummyCoin.balanceOf(address(alice)), 1_000_000);
    }
}
