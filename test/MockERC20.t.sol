// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "lib/forge-std/src/Test.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 private _mockERC20;
    address alice = makeAddr("Alice");

    function setUp() public {
        _mockERC20 = new MockERC20();
    }

    function test_name_returnsName() public {
        assertEq(_mockERC20.name(), "DummyCoin", "Name mismatch");
    }

    function test_symbol_returnsSymbol() public {
        assertEq(_mockERC20.symbol(), "COIN", "Symbol mismatch");
    }

    function test_mintTo_succeeds() public {
        _mockERC20.mintTo(address(alice));
        assertEq(_mockERC20.balanceOf(address(alice)), 1_000_000, "Balance mismatch");
    }
}
