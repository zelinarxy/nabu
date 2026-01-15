// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@solady/src/auth/Ownable.sol";
import {LibZip} from "@solady/src/utils/LibZip.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "../src/Ashurbanipal.sol";
import "../src/Enkidu.sol";
import "../src/Nabu.sol";
import "../src/dummy/DummyCoin.sol";
import "../src/dummy/DummyNft.sol";
import "../src/Humbaba.sol";


// TODO: mismatch messages on assertEq
contract EnkiduTest is Ownable, Test {
    Ashurbanipal private _ashurbanipal;
    Enkidu private _enkidu;
    Nabu private _nabu;
    Humbaba private _humbaba;

    DummyCoin private _cult;

    DummyNft private _aura;
    DummyNft private _cigawrette;
    DummyNft private _milady;
    DummyNft private _pixelady;
    DummyNft private _radbro;
    DummyNft private _remilio;
    DummyNft private _schizoposter;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address mallory = makeAddr("Mallory");

    function setUp() public {
        vm.roll(0);
        _nabu = new Nabu();
        address nabuAddress = address(_nabu);

        _ashurbanipal = new Ashurbanipal(nabuAddress);
        _nabu.updateAshurbanipalAddress(address(_ashurbanipal));

        vm.startPrank(alice, alice);
        _humbaba = new Humbaba("https://foo.bar/");
        _enkidu = new Enkidu(address(_ashurbanipal), address(_humbaba));

        uint256 workId = _nabu.createWork(
            "Miguel de Cervantes",
            "Original title: El ingenioso hidalgo don Quijote de la Mancha",
            "Don Quijote",
            1_000_000,
            "https://foo.bar/{id}.json",
            10_000,
            address(_enkidu)
        );

        _enkidu.updatePrice(workId, 0.05 ether);
        _enkidu.updateActive(workId, true);

        bytes memory dummyCoinBytecode = type(DummyCoin).runtimeCode;

        _cult = DummyCoin(CULT);
        vm.etch(CULT, dummyCoinBytecode);

        bytes memory dummyNftBytecode = type(DummyNft).runtimeCode;

        _aura = DummyNft(AURA);
        vm.etch(AURA, dummyNftBytecode);

        _cigawrette = DummyNft(CIGAWRETTE);
        vm.etch(CIGAWRETTE, dummyNftBytecode);

        _milady = DummyNft(MILADY);
        vm.etch(MILADY, dummyNftBytecode);

        _pixelady = DummyNft(PIXELADY);
        vm.etch(PIXELADY, dummyNftBytecode);

        _radbro = DummyNft(RADBRO);
        vm.etch(RADBRO, dummyNftBytecode);

        _remilio = DummyNft(REMILIO);
        vm.etch(REMILIO, dummyNftBytecode);

        _schizoposter = DummyNft(SCHIZOPOSTER);
        vm.etch(SCHIZOPOSTER, dummyNftBytecode);

        vm.stopPrank();
    }

    function testUpdateActive() public {
        vm.startPrank(alice, alice);
        _enkidu.updateActive(1, false);
        assertFalse(_enkidu.active(1));

        _enkidu.updateActive(1, true);
        assertTrue(_enkidu.active(1));
        vm.stopPrank();
    }

    function testUpdateActiveNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updateActive(1, true);
    }

    function testUpdatePrice() public {
        assertEq(_enkidu.prices(1), 0.05 ether);

        vm.prank(alice);
        _enkidu.updatePrice(1, 100 ether);
        assertEq(_enkidu.prices(1), 100 ether);
    }

    function testUpdatePriceNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updatePrice(1, 100 ether);
    }

    function testUpdateAshurbanipalAddress() public {
        assertEq(_enkidu.ashurbanipalAddress(), address(_ashurbanipal));

        vm.prank(alice);
        _enkidu.updateAshurbanipalAddress(address(69));
        assertEq(_enkidu.ashurbanipalAddress(), address(69));
    }

    function testUpdateAshurbanipalAddressNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updateAshurbanipalAddress(address(69));
    }

    function testAdminMint() public {
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 0);

        vm.prank(alice);
        _enkidu.adminMint(1, 20, address(bob));
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 20);
    }

    function testAdminMintNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.adminMint(1, 20, address(bob));
    }

    function testAdminMintZeroCount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        _enkidu.adminMint(1, 0, address(bob));
    }

    function testMint() public {
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 0);

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.prank(bob);

        _enkidu.mint{value: 20 * 0.05 ether}(1, 20, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 20);
    }

    function testMintWhitelistedHumbaba() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMinWhitelistedCult() public {
        vm.prank(alice);
        _cult.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Cult);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedAura() public {
        vm.prank(alice);
        _aura.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Aura);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedCigawrette() public {
        vm.prank(alice);
        _cigawrette.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Cigawrette);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedMilady() public {
        vm.prank(alice);
        _milady.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Milady);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedPixelady() public {
        vm.prank(alice);
        _pixelady.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Pixelady);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedRadbro() public {
        vm.prank(alice);
        _radbro.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Radbro);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedRemilio() public {
        vm.prank(alice);
        _remilio.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Remilio);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedSchizoposter() public {
        vm.prank(alice);
        _schizoposter.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Schizoposter);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedAny() public {
        vm.prank(alice);
        _schizoposter.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Any);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedTwoBatches() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.startPrank(bob, bob);

        _enkidu.mint(1, 2, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 2);

        _enkidu.mint(1, 5, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7);
    }

    function testMintWhitelistedExtraMints() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);

        _enkidu.mint{value: 10 * 0.05 ether}(1, 17, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 17);
    }

    function testMintWhitelistedComplexBatches() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));
        vm.deal(address(bob), 2 * 0.05 ether);

        vm.startPrank(bob, bob);
        _enkidu.mint(1, 2, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 2);

        _enkidu.mint{value: 0.05 ether}(1, 6, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 8);

        _enkidu.mint{value: 0.05 ether}(1, 1, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 9);
        vm.stopPrank();
    }

    function testMintOverLimit() public {
        vm.deal(address(bob), 70 * 0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(OverLimit.selector));
        vm.prank(bob);
        _enkidu.mint{value: 69 * 0.05 ether}(1, 70, address(bob), WhitelistedToken.None);
    }

    function testMintInsufficientFunds() public {
        vm.deal(address(bob), 0.04 ether);
        vm.expectRevert(abi.encodeWithSelector(InsufficientFunds.selector));
        vm.prank(bob);
        _enkidu.mint{value: 0.04 ether}(1, 1, address(bob), WhitelistedToken.None);
    }

    function testMintZeroCount() public {
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        vm.prank(bob);
        _enkidu.mint(1, 0, address(bob), WhitelistedToken.None);
    }

    function testMintInactive() public {
        vm.prank(alice);
        _enkidu.updateActive(1, false);

        vm.deal(address(bob), 0.05 ether);
        vm.expectRevert(abi.encodeWithSelector(Inactive.selector));
        vm.prank(bob);
        _enkidu.mint{value: 0.05 ether}(1, 1, address(bob), WhitelistedToken.None);
    }

    function testWithdrawSome() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);
        assertEq(address(_enkidu).balance, 10 * 0.05 ether);

        vm.prank(alice);
        _enkidu.withdraw(0.05 ether);
        assertEq(address(alice).balance, 0.05 ether);
        assertEq(address(_enkidu).balance, 9 * 0.05 ether);
    }

    function testWithdrawAll() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(alice);
        _enkidu.withdraw(0);
        assertEq(address(alice).balance, 10 * 0.05 ether);
        assertEq(address(_enkidu).balance, 0);
    }

    function testWithdrawNotOwner() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.withdraw(10 * 0.05 ether);
    }

    function testUpdateHumbaba() public {
        assertEq(_enkidu.humbabaAddress(), address(_humbaba));

        vm.prank(alice);
        _enkidu.updateHumbaba(address(123));
        assertEq(_enkidu.humbabaAddress(), address(123));
    }

    function testUpdateHumbabaNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updateHumbaba(address(666));
    }

    function testSecondWork() public {
        vm.startPrank(alice, alice);
        uint256 workId = _nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            address(_enkidu)
        );

        _enkidu.updateActive(workId, true);
        _enkidu.updatePrice(workId, 0.1 ether);
        vm.stopPrank();

        assertEq(_ashurbanipal.balanceOf(address(_enkidu), workId), 50);

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.startPrank(bob, bob);

        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 10);

        _enkidu.mint{value: 5 * 0.1 ether}(workId, 5, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), workId), 5);
    }
}
