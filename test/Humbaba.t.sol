// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {Test} from "forge-std/Test.sol";
import "../src/Humbaba.sol";

// TODO: mismatch messages on assertEq
contract HumbabaTest is Ownable, Test {
    Humbaba public humbaba;
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address mallory = makeAddr("Mallory");

    function setUp() public {
        vm.prank(alice);
        humbaba = new Humbaba("https://foo.bar/");
    }

    function testName() public {
        assertEq(humbaba.name(), "Humbaba");
    }

    function testSymbol() public {
        assertEq(humbaba.symbol(), "HUMB");
    }

    function testAdminMintTo() public {
        vm.prank(alice);
        humbaba.adminMintTo(address(bob));
        assertEq(humbaba.balanceOf(address(bob)), 1);
    }

    function testAdminMintToNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        humbaba.adminMintTo(address(bob));
    }

    function testTokenURI() public {
        vm.prank(alice);
        humbaba.adminMintTo(address(bob));
        assertEq(humbaba.tokenURI(1), "https://foo.bar/1");
    }

    function testTokenURINonExistent() public {
        vm.expectRevert(abi.encodeWithSelector(NonExistentToken.selector));
        humbaba.tokenURI(2);
    }

    function testUpdateBaseURI() public {
        assertEq(humbaba.baseURI(), "https://foo.bar/");
        vm.prank(alice);
        humbaba.updateBaseURI("https://baz.qux/");
        assertEq(humbaba.baseURI(), "https://baz.qux/");
    }

    function testUpdateBaseURINotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        humbaba.updateBaseURI("https://baz.qux/");
    }
}
