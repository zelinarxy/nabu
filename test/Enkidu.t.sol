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

contract NabuTest is Ownable, Test {
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

    // function testAdminMint() public {
    //     assertEq(address(0), address(1));
    // }

    // function testAdminMintNotOwner() public {
    //     assertEq(address(0), address(1));
    // }

    // function testAdminMintZeroCount() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMint() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintWhitelistedNFT() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintWhitelistedFungible() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintWhitelistedExtraMints() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintOverLimit() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintZeroCount() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintNotActive() public {
    //     assertEq(address(0), address(1));
    // }

    // function testMintInsufficientFunds() public {
    //     assertEq(address(0), address(1));
    // }

    // function testWithdrawSome() public {
    //     assertEq(address(0), address(1));
    // }

    // function testWithdrawAll() public {
    //     assertEq(address(0), address(1));
    // }

    // function testWithdrawNotOwner() public {
    //     assertEq(address(0), address(1));
    // }
}
