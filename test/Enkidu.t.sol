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
    address charlie = makeAddr("Charlie");
    address dave = makeAddr("Dave");
    address frank = makeAddr("Frank");
    address mallory = makeAddr("Mallory");

    modifier prank(address addr) {
        vm.startPrank(addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.roll(0);
        nabu = new Nabu();
        address nabuAddress = address(nabu);
        ashurbanipal = new Ashurbanipal(nabuAddress);
        nabu.updateAshurbanipalAddress(address(ashurbanipal));
        testNft = new TestNft();
    }

    function createWork(address to) private returns (uint256) {
        uint256 workId = nabu.createWork(
            "Miguel de Cervantes",
            "Original title: El ingenioso hidalgo don Quijote de la Mancha",
            "Don Quijote",
            1_000_000,
            "https://foo.bar/{id}.json",
            10_000,
            to
        );

        return workId;
    }

    function createWorkWithEnkiduAsAlice() private prank(alice) returns (uint256) {
        enkidu = new Enkidu(address(ashurbanipal), address(testNft));
        uint256 workId = createWork(address(enkidu));
        enkidu.updatePrice(workId, 0.05 ether);
        enkidu.updateActive(workId, true);
        return workId;
    }

    function testUpdateActive() public {
        vm.startPrank(alice, alice);
        enkidu = new Enkidu(address(ashurbanipal), address(testNft));
        uint256 workId = createWork(address(enkidu));
        assertFalse(enkidu.active(workId));

        enkidu.updateActive(workId, true);
        assertTrue(enkidu.active(workId));
    }

    function testUpdateActivePause() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.prank(alice);
        enkidu.updateActive(workId, false);
        assertFalse(enkidu.active(workId));
    }

    function testUpdateActiveNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.startPrank(mallory, mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateActive(workId, true);
    }

    function testUpdatePrice() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        assertEq(enkidu.prices(workId), 0.05 ether);

        vm.prank(alice);
        enkidu.updatePrice(workId, 100 ether);
        assertEq(enkidu.prices(workId), 100 ether);
    }

    function testUpdatePriceNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.startPrank(mallory, mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updatePrice(workId, 100 ether);
    }

    function testUpdateAshurbanipalAddress() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        assertEq(enkidu.ashurbanipalAddress(), address(ashurbanipal));

        vm.prank(alice);
        enkidu.updateAshurbanipalAddress(address(69));
        assertEq(enkidu.ashurbanipalAddress(), address(69));
    }

    function testUpdateAshurbanipalAddressNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.startPrank(mallory, mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateAshurbanipalAddress(address(69));
    }

    function testAdminMint() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        assertEq(ashurbanipal.balanceOf(address(bob), workId), 0);

        vm.prank(alice);
        enkidu.adminMint(workId, 20, address(bob));
        assertEq(ashurbanipal.balanceOf(address(bob), workId), 20);
    }

    function testAdminMintNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.adminMint(workId, 20, address(bob));
    }

    function testAdminMintZeroCount() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        enkidu.adminMint(workId, 0, address(bob));
    }

    function testMint() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 0);

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.prank(bob);

        enkidu.mint{value: 20 * 0.05 ether}(workId, 20, address(bob), WhitelistedToken.None);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 20);
    }

    function testMintWhitelisted() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        testNft.mintTo(address(bob));

        vm.startPrank(bob, bob);
        enkidu.mint(workId, 7, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedTwoBatches() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        testNft.mintTo(address(bob));

        vm.startPrank(bob, bob);
        enkidu.mint(workId, 2, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 2);

        enkidu.mint(workId, 5, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedExtraMints() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        testNft.mintTo(address(bob));

        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);

        enkidu.mint{value: 10 * 0.05 ether}(workId, 17, address(bob), WhitelistedToken.TestNft);
        assertEq(ashurbanipal.balanceOf(address(bob), 1), 17);
    }

    function testMintOverLimit() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.deal(address(bob), 70 *  0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(OverLimit.selector));
        vm.prank(bob);
        enkidu.mint{value: 69 * 0.05 ether}(workId, 70, address(bob), WhitelistedToken.None);
    }

    function testMintInsufficientFunds() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.deal(address(bob), 0.04 ether);
        vm.expectRevert(abi.encodeWithSelector(InsufficientFunds.selector));
        vm.prank(bob);
        enkidu.mint{value: 0.04 ether}(workId, 1, address(bob), WhitelistedToken.None);
    }

    function testMintZeroCount() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        vm.prank(bob);
        enkidu.mint(workId, 0, address(bob), WhitelistedToken.None);
    }

    function testMintInactive() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.prank(alice);
        enkidu.updateActive(workId, false);

        vm.deal(address(bob), 0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(Inactive.selector));
        vm.prank(bob);
        enkidu.mint{ value: 0.05 ether}(workId, 1, address(bob), WhitelistedToken.None);
    }

    function testWithdrawSome() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(workId, 10, address(bob), WhitelistedToken.None);
        assertEq(address(enkidu).balance, 10 * 0.05 ether);

        vm.prank(alice);
        enkidu.withdraw(0.05 ether);
        assertEq(address(alice).balance, 0.05 ether);
        assertEq(address(enkidu).balance, 9 * 0.05 ether);
    }

    function testWithdrawAll() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(workId, 10, address(bob), WhitelistedToken.None);

        vm.prank(alice);
        enkidu.withdraw(10 * 0.05 ether);
        assertEq(address(alice).balance, 10 * 0.05 ether);
        assertEq(address(enkidu).balance, 0);
    }

    function testWithdrawNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        enkidu.mint{value: 10 * 0.05 ether}(workId, 10, address(bob), WhitelistedToken.None);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.withdraw(10 * 0.05 ether);
    }

    function testUpdateTestNft() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        assertEq(enkidu.testNftAddress(), address(testNft));

        vm.prank(alice);
        enkidu.updateTestNft(address(123));
        assertEq(enkidu.testNftAddress(), address(123));
    }

    function testUpdateTestNftNotOwner() public {
        uint256 workId = createWorkWithEnkiduAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        enkidu.updateTestNft(address(666));
    }

    // TODO: one enkidu deployment holding multiple ids
}
