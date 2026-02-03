// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LibZip} from "lib/solady/src/utils/LibZip.sol";
import {Ownable} from "lib/solady/src/auth/Ownable.sol";
import {SSTORE2} from "lib/solady/src/utils/SSTORE2.sol";
import {Test, console2} from "lib/forge-std/src/Test.sol";

import {Ashurbanipal} from "../src/Ashurbanipal.sol";
import {
    AURA,
    CIGAWRETTE,
    CULT,
    Enkidu,
    Inactive,
    InsufficientFunds,
    MILADY,
    OverLimit,
    PIXELADY,
    RADBRO,
    REMILIO,
    SCHIZOPOSTER,
    WhitelistedToken,
    ZeroCount
} from "../src/Enkidu.sol";
import {Humbaba, NonExistentToken} from "../src/Humbaba.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {Nabu} from "../src/Nabu.sol";

contract EnkiduTest is Ownable, Test {
    Ashurbanipal private _ashurbanipal;
    Enkidu private _enkidu;
    Nabu private _nabu;
    Humbaba private _humbaba;

    MockERC20 private _cult;

    MockERC721 private _aura;
    MockERC721 private _cigawrette;
    MockERC721 private _milady;
    MockERC721 private _pixelady;
    MockERC721 private _radbro;
    MockERC721 private _remilio;
    MockERC721 private _schizoposter;

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

        bytes memory mockERC20Bytecode = type(MockERC20).runtimeCode;

        _cult = MockERC20(CULT);
        vm.etch(CULT, mockERC20Bytecode);

        bytes memory mockERC721Bytecode = type(MockERC721).runtimeCode;

        _aura = MockERC721(AURA);
        vm.etch(AURA, mockERC721Bytecode);

        _cigawrette = MockERC721(CIGAWRETTE);
        vm.etch(CIGAWRETTE, mockERC721Bytecode);

        _milady = MockERC721(MILADY);
        vm.etch(MILADY, mockERC721Bytecode);

        _pixelady = MockERC721(PIXELADY);
        vm.etch(PIXELADY, mockERC721Bytecode);

        _radbro = MockERC721(RADBRO);
        vm.etch(RADBRO, mockERC721Bytecode);

        _remilio = MockERC721(REMILIO);
        vm.etch(REMILIO, mockERC721Bytecode);

        _schizoposter = MockERC721(SCHIZOPOSTER);
        vm.etch(SCHIZOPOSTER, mockERC721Bytecode);

        vm.stopPrank();
    }

    function test_updateActive_updatesCorrectly() public {
        vm.startPrank(alice, alice);
        _enkidu.updateActive(1, false);
        assertFalse(_enkidu.active(1));

        _enkidu.updateActive(1, true);
        assertTrue(_enkidu.active(1));
        vm.stopPrank();
    }

    function test_updateActive_reverts_whenCallerIsNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updateActive(1, true);
    }

    function test_updatePrice_updatesCorrectly() public {
        assertEq(_enkidu.prices(1), 0.05 ether, "Before price mismatch");

        vm.prank(alice);
        _enkidu.updatePrice(1, 100 ether);
        assertEq(_enkidu.prices(1), 100 ether, "After price mismatch");
    }

    function test_updatePrice_reverts_whenCallerIsNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updatePrice(1, 100 ether);
    }

    function test_updateAshurbanipalAddress_updatesCorrectly() public {
        assertEq(_enkidu.getAshurbanipalAddress(), address(_ashurbanipal), "Before address mismatch");

        vm.prank(alice);
        _enkidu.updateAshurbanipalAddress(address(69));
        assertEq(_enkidu.getAshurbanipalAddress(), address(69), "After address mismatch");
    }

    function test_updateAshurbanipalAddress_reverts_whenCallerIsNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.updateAshurbanipalAddress(address(69));
    }

    function test_adminMint_succeeds() public {
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 0, "Before balance mismatch");

        vm.prank(alice);
        _enkidu.adminMint(1, 20, address(bob));
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 20, "After balance mismatch");
    }

    function test_adminMint_reverts_whenCallerIsNotOwner() public {
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.adminMint(1, 20, address(bob));
    }

    function test_adminMint_reverts_whenCalledWithZeroCount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroCount.selector));
        _enkidu.adminMint(1, 0, address(bob));
    }

    function test_mint_succeeds() public {
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 0, "Before balance mismatch");

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.prank(bob);

        _enkidu.mint{value: 20 * 0.05 ether}(1, 20, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 20, "After balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsHumbaba() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsCult() public {
        vm.prank(alice);
        _cult.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Cult);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsAura() public {
        vm.prank(alice);
        _aura.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Aura);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsCigawrette() public {
        vm.prank(alice);
        _cigawrette.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Cigawrette);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsMilady() public {
        vm.prank(alice);
        _milady.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Milady);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsPixelady() public {
        vm.prank(alice);
        _pixelady.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Pixelady);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsRadbro() public {
        vm.prank(alice);
        _radbro.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Radbro);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsRemilio() public {
        vm.prank(alice);
        _remilio.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Remilio);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCallerOwnsSchizoposter() public {
        vm.prank(alice);
        _schizoposter.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Schizoposter);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenCalledWithAny() public {
        vm.prank(alice);
        _schizoposter.mintTo(address(bob));

        vm.prank(bob);
        _enkidu.mint(1, 7, address(bob), WhitelistedToken.Any);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Balance mismatch");
    }

    function test_mint_mintsForFree_whenSplitIntoBatches() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.startPrank(bob, bob);

        _enkidu.mint(1, 2, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 2, "First batch balance mismatch");

        _enkidu.mint(1, 5, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 7, "Second batch balance mismatch");
    }

    function testMintWhitelistedExtraMints() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));

        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);

        _enkidu.mint{value: 10 * 0.05 ether}(1, 17, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 17, "Balance mismatch");
    }

    function testMintWhitelistedComplexBatches() public {
        vm.prank(alice);
        _humbaba.adminMintTo(address(bob));
        vm.deal(address(bob), 2 * 0.05 ether);

        vm.startPrank(bob, bob);
        _enkidu.mint(1, 2, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 2, "First batch balance mismatch");

        _enkidu.mint{value: 0.05 ether}(1, 6, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 8, "Second batch balance mismatch");

        _enkidu.mint{value: 0.05 ether}(1, 1, address(bob), WhitelistedToken.Humbaba);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 9, "Third batch balance mismatch");
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
        assertEq(address(_enkidu).balance, 10 * 0.05 ether, "Before contract balance mismatch");

        vm.prank(alice);
        _enkidu.withdraw(0.05 ether, address(0));
        assertEq(address(alice).balance, 0.05 ether, "After Alice balance mismatch");
        assertEq(address(_enkidu).balance, 9 * 0.05 ether, "After contract balance mismatch");
    }

    function testWithdrawAll() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(alice);
        _enkidu.withdraw(0, address(0));
        assertEq(address(alice).balance, 10 * 0.05 ether, "Alice balance mismatch");
        assertEq(address(_enkidu).balance, 0, "Contract balance mismatch");
    }

    function testWithdrawNotOwner() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _enkidu.withdraw(10 * 0.05 ether, address(0));
    }

    function testWithdrawToSpecifiedAddress() public {
        vm.deal(address(bob), 10 * 0.05 ether);
        vm.prank(bob);
        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);

        vm.prank(alice);
        _enkidu.withdraw(10 * 0.05 ether, address(bob));
        assertEq(address(bob).balance, 10 * 0.05 ether, "Bob balance mismatch");
        assertEq(address(_enkidu).balance, 0, "Contract balance mismatch");
    }

    function testUpdateHumbaba() public {
        assertEq(_enkidu.getHumbabaAddress(), address(_humbaba), "Before address mismatch");

        vm.prank(alice);
        _enkidu.updateHumbaba(address(123));
        assertEq(_enkidu.getHumbabaAddress(), address(123), "After address mismatch");
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

        assertEq(_ashurbanipal.balanceOf(address(_enkidu), workId), 50, "Second work Enkidu balance mismatch");

        vm.deal(address(bob), 20 * 0.05 ether);
        vm.startPrank(bob, bob);

        _enkidu.mint{value: 10 * 0.05 ether}(1, 10, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), 1), 10, "First work Bob balance mismatch");

        _enkidu.mint{value: 5 * 0.1 ether}(workId, 5, address(bob), WhitelistedToken.None);
        assertEq(_ashurbanipal.balanceOf(address(bob), workId), 5, "Second work Bob balance mismatch");
    }
}
