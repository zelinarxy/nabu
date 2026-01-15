// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/dummy/DummyNft.sol";

contract DummyNftTest is Test {
    DummyNft private _dummyNft;
    address alice = makeAddr("Alice");

    function setUp() public {
        _dummyNft = new DummyNft();
    }

    function testName() public {
        assertEq(_dummyNft.name(), "DummyNft", "Name mismatch");
    }

    function testSymbol() public {
        assertEq(_dummyNft.symbol(), "DUMMY", "Symbol mismatch");
    }

    function testMintTo() public {
        _dummyNft.mintTo(address(alice));
        assertEq(_dummyNft.balanceOf(address(alice)), 1, "Balance mismatch");
    }

    function testTokenURI() public {
        _dummyNft.mintTo(address(alice));
        assertEq(_dummyNft.tokenURI(1), "", "URI mismatch");
    }
}
