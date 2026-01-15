// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/dummy/DummyCoin.sol";

contract DummyCoinTest is Test {
    DummyCoin private _dummyCoin;
    address alice = makeAddr("Alice");

    function setUp() public {
        _dummyCoin = new DummyCoin();
    }

    function testName() public {
        assertEq(_dummyCoin.name(), "DummyCoin", "Name mismatch");
    }

    function testSymbol() public {
        assertEq(_dummyCoin.symbol(), "COIN", "Symbol mismatch");
    }

    function testMintTo() public {
        _dummyCoin.mintTo(address(alice));
        assertEq(_dummyCoin.balanceOf(address(alice)), 1_000_000, "Balance mismatch");
    }
}
