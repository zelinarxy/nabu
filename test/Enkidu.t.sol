// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@solady/src/auth/Ownable.sol";
import {LibZip} from "@solady/src/utils/LibZip.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "../src/Ashurbanipal.sol";
import "../src/Enkidu.sol";
import "../src/Nabu.sol";
import "../src/TestNft.sol";

contract EnkiduTest is Ownable, Test {
    Ashurbanipal public ashurbanipal;
    Enkidu public enkidu;
    Nabu public nabu;
    TestNft public testNft;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address mallory = makeAddr("Mallory");

    function setUp() public {
        vm.roll(0);
        nabu = new Nabu();
        address nabuAddress = address(nabu);

        ashurbanipal = new Ashurbanipal(nabuAddress);
        nabu.updateAshurbanipalAddress(address(ashurbanipal));
        testNft = new TestNft();

        vm.startPrank(alice, alice);
        enkidu = new Enkidu(address(ashurbanipal), address(testNft));

        uint256 workId = nabu.createWork(
            "Miguel de Cervantes",
            "Original title: El ingenioso hidalgo don Quijote de la Mancha",
            "Don Quijote",
            1_000_000,
            "https://foo.bar/{id}.json",
            10_000,
            address(enkidu)
        );

        enkidu.updatePrice(workId, 0.05 ether);
        enkidu.updateActive(workId, true);
        vm.stopPrank();
    }

    function testUpdateActive() public {        
        vm.startPrank(alice, alice);
        enkidu.updateActive(1, false);
        assertFalse(enkidu.active(1));

        enkidu.updateActive(1, true);
        assertTrue(enkidu.active(1));
        vm.stopPrank();
    }

    function testUpdateActiveNotOwner() public {        
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateActive(1, true);
    }

    function testUpdatePrice() public {        
        assertEq(enkidu.prices(1), 0.05 ether);

        vm.prank(alice);
        enkidu.updatePrice(1, 100 ether);
        assertEq(enkidu.prices(1), 100 ether);
    }

    function testUpdatePriceNotOwner() public {        
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updatePrice(1, 100 ether);
    }

    function testUpdateAshurbanipalAddress() public {        
        assertEq(enkidu.ashurbanipalAddress(), address(ashurbanipal));

        vm.prank(alice);
        enkidu.updateAshurbanipalAddress(address(69));
        assertEq(enkidu.ashurbanipalAddress(), address(69));
    }

    function testUpdateAshurbanipalAddressNotOwner() public {        
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateAshurbanipalAddress(address(69));
    }

    function testAdminMint() public {        
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 0);

        vm.prank(alice);
        enkidu.adminMint(1, 20, address(bob));
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 20);
    }

    function testAdminMintNotOwner() public {        
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.adminMint(1, 20, address(bob));
    }

    function testAdminMintZeroCount() public {        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        enkidu.adminMint(1, 0, address(bob));
    }

    function testMint() public {        
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 0);

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.prank(bob);

        enkidu.mint{value: 20 * 0.05 ether}(1, 20, address(bob), WhitelistedToken.None);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 20);
    }

    function testMintWhitelisted() public {        
        testNft.mintTo(address(bob));

        vm.prank(bob);
        enkidu.mint(1, 7, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedTwoBatches() public {        
        testNft.mintTo(address(bob));

        vm.startPrank(bob, bob);

        enkidu.mint(1, 2, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 2);

        enkidu.mint(1, 5, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedExtraMints() public {        
        testNft.mintTo(address(bob));

        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);

        enkidu.mint{value: 10 * 0.05 ether}(1, 17, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 17);
    }

    function testMintWhitelistedComplexBatches() public {        
        testNft.mintTo(address(bob));
        vm.deal(address(bob), 2 * 0.05 ether);

        vm.startPrank(bob, bob);
        enkidu.mint(1, 2, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 2);

        enkidu.mint{value: 0.05 ether}(1, 6, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 8);

        enkidu.mint{value: 0.05 ether}(1, 1, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 9);
        vm.stopPrank();
    }

    function testMintOverLimit() public {        
        vm.deal(address(bob), 70 * 0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(OverLimit.selector));
        vm.prank(bob);
        enkidu.mint{value: 69 * 0.05 ether}(1, 70, address(bob), WhitelistedToken.None);
    }

    function testMintInsufficientFunds() public {        
        vm.deal(address(bob), 0.04 ether);
        vm.expectRevert(abi.encodeWithSelector(InsufficientFunds.selector));
        vm.prank(bob);
        enkidu.mint{value: 0.04 ether}(1, 1, address(bob), WhitelistedToken.None);
    }

    function testMintZeroCount() public {        
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        vm.prank(bob);
        enkidu.mint(1, 0, address(bob), WhitelistedToken.None);
    }

    function testMintInactive() public {        
        vm.prank(alice);
        enkidu.updateActive(1, false);

        vm.deal(address(bob), 0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(Inactive.selector));
        vm.prank(bob);
        enkidu.mint{value: 0.05 ether}(1, 1, address(bob), WhitelistedToken.None);
    }

    function testWithdrawSome() public {        
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);
        assertEq(address(enkidu).balance, 10 * 0.05 ether);

        vm.prank(alice);
        enkidu.withdraw(0.05 ether);
        assertEq(address(alice).balance, 0.05 ether);
        assertEq(address(enkidu).balance, 9 * 0.05 ether);
    }

    function testWithdrawAll() public {        
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(alice);
        enkidu.withdraw(0);
        assertEq(address(alice).balance, 10 * 0.05 ether);
        assertEq(address(enkidu).balance, 0);
    }

    function testWithdrawNotOwner() public {        
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.withdraw(10 * 0.05 ether);
    }

    function testUpdateTestNft() public {        
        assertEq(enkidu.testNftAddress(), address(testNft));

        vm.prank(alice);
        enkidu.updateTestNft(address(123));
        assertEq(enkidu.testNftAddress(), address(123));
    }

    function testUpdateTestNftNotOwner() public {        
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateTestNft(address(666));
    }

    function testSecondWork() public {
        vm.startPrank(alice, alice);
        uint256 workId = nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            address(enkidu)
        );

        enkidu.updateActive(workId, true);
        enkidu.updatePrice(workId, 0.1 ether);
        vm.stopPrank();

        assertEq(ashurbanipal.balanceOf(address(enkidu), workId), 50);

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.startPrank(bob, bob);

        enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 10);

        enkidu.mint{value: 5 * 0.1 ether}(workId, 5, address(bob), WhitelistedToken.None);
        assertEq(ashurbanipal.balanceOf(address(bob), workId), 5);
    }
}
