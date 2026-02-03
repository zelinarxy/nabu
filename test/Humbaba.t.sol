// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {Test} from "lib/forge-std/src/Test.sol";

import {Humbaba, NonExistentToken} from "../src/Humbaba.sol";

contract HumbabaTest is Ownable, Test {
    Humbaba private _humbaba;
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address mallory = makeAddr("Mallory");

    function setUp() public {
        vm.prank(alice);
        _humbaba = new Humbaba("https://foo.bar/");
    }

    function testName() public {
        assertEq(_humbaba.name(), "Humbaba", "Name mismatch");
    }

    function testSymbol() public {
        assertEq(_humbaba.symbol(), "HUMB", "Symbol mismatch");
    }

    function testAdminMintTo() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));
        assertEq(_humbaba.balanceOf(address(bob)), 1, "Bob balance mismatch");
    }

    function testAdminMintToNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _humbaba.adminMintTo(address(bob));
    }

    function testTokenURI() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));
        assertEq(_humbaba.tokenURI(1), "https://foo.bar/1", "URI mismatch");
    }

    function testTokenURINonExistent() public {
        vm.expectRevert(abi.encodeWithSelector(NonExistentToken.selector));
        _humbaba.tokenURI(2);
    }

    function testUpdateBaseURI() public {
        assertEq(_humbaba.baseURI(), "https://foo.bar/", "Before URI mismatch");
        vm.prank(alice);
        _humbaba.updateBaseURI("https://baz.qux/");
        assertEq(_humbaba.baseURI(), "https://baz.qux/", "After URI mismatch");
    }

    function testUpdateBaseURINotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _humbaba.updateBaseURI("https://baz.qux/");
    }
}
