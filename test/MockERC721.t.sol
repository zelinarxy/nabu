// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {MockERC721} from "./mocks/MockERC721.sol";

contract MockERC721Test is Test {
    MockERC721 private _mockERC721;
    address alice = makeAddr("Alice");

    function setUp() public {
        _mockERC721 = new MockERC721();
    }

    function testName() public {
        assertEq(_mockERC721.name(), "DummyNft", "Name mismatch");
    }

    function testSymbol() public {
        assertEq(_mockERC721.symbol(), "DUMMY", "Symbol mismatch");
    }

    function testMintTo() public {
        _mockERC721.mintTo(address(alice));
        assertEq(_mockERC721.balanceOf(address(alice)), 1, "Balance mismatch");
    }

    function testTokenURI() public {
        _mockERC721.mintTo(address(alice));
        assertEq(_mockERC721.tokenURI(1), "https://foo.bar/1", "URI mismatch");
    }
}
