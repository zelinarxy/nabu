// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@solady/src/auth/Ownable.sol";
import {LibZip} from "@solady/src/utils/LibZip.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "../src/Ashurbanipal.sol";
import "../src/Nabu.sol";

contract AshurbanipalTest is Ownable, Test {
    Ashurbanipal private _ashurbanipal;
    Nabu private _nabu;

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
        _nabu = new Nabu();
        address nabuAddress = address(_nabu);
        _ashurbanipal = new Ashurbanipal(nabuAddress);
        _nabu.updateAshurbanipalAddress(address(_ashurbanipal));
    }

    bytes passageOne = bytes(
        unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad."
    );
    bytes passageOneCompressed = LibZip.flzCompress(passageOne);

    bytes passageOneMalicious = bytes(unicode"¡Soy muy malo y quiero destruir el patrimonio literario de España!");
    bytes passageOneMaliciousCompressed = LibZip.flzCompress(passageOneMalicious);

    function createWork(address to) private returns (uint256) {
        uint256 workId = _nabu.createWork(
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

    function distributePasses(uint256 workId) private {
        _ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        _ashurbanipal.safeTransferFrom(alice, charlie, workId, 2_000, "");
        _ashurbanipal.safeTransferFrom(alice, dave, workId, 500, "");
        _ashurbanipal.safeTransferFrom(alice, mallory, workId, 666, "");
    }

    function createWorkAndDistributePassesAsAlice() private prank(alice) returns (uint256) {
        uint256 workId = createWork(alice);
        distributePasses(workId);
        return workId;
    }

    function testUpdateUriNotNabu() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(NotNabu.selector));
        _ashurbanipal.updateUri(workId, "https://hmmm.cool/{id}.json");
    }

    function testGetNabuAddress() public {
        address nabuAddress = _ashurbanipal.getNabuAddress();
        assertEq(nabuAddress, address(_nabu), "Nabu address mismatch");
    }

    function testMintNotNabu() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(NotNabu.selector));
        _ashurbanipal.mint(mallory, workId, 100, "https://yes.wowee/{id}.json");
    }

    function testTransfer() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(_ashurbanipal.balanceOf(bob, workId), 1_000, "Bob pass balance before mismatch");
        assertEq(_ashurbanipal.balanceOf(charlie, workId), 2_000, "Charlie pass balance before mismatch");

        vm.prank(bob);
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        assertEq(_ashurbanipal.balanceOf(bob, workId), 995, "Bob pass balance after mismatch");
        assertEq(_ashurbanipal.balanceOf(charlie, workId), 2_005, "Charlie pass balance after mismatch");
    }

    function testBatchTransfer() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = _nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            bob
        );

        assertEq(_ashurbanipal.balanceOf(bob, workId), 1_000, "Bob work one pass balance before mismatch");
        assertEq(_ashurbanipal.balanceOf(bob, workIdTwo), 50, "Bob work two pass balance before mismatch");
        assertEq(_ashurbanipal.balanceOf(frank, workId), 0, "Frank work one pass balance before mismatch");
        assertEq(_ashurbanipal.balanceOf(frank, workIdTwo), 0, "Frank work two pass balance before mismatch");

        uint256[] memory workIds = new uint256[](2);
        workIds[0] = workId;
        workIds[1] = workIdTwo;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 20;

        vm.prank(bob);
        _ashurbanipal.safeBatchTransferFrom(bob, frank, workIds, amounts, "");

        assertEq(_ashurbanipal.balanceOf(bob, workId), 999, "Bob work one pass balance after mismatch");
        assertEq(_ashurbanipal.balanceOf(bob, workIdTwo), 30, "Bob work two pass balance after mismatch");
        assertEq(_ashurbanipal.balanceOf(frank, workId), 1, "Frank work one pass balance after mismatch");
        assertEq(_ashurbanipal.balanceOf(frank, workIdTwo), 20, "Frank work two pass balance after mismatch");
    }

    function testTransferBlacklistedSender() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");
    }

    function testTransferBlacklistedRecipient() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, charlie, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");
    }

    function testBatchTransferBlacklistedSender() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = _nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            bob
        );

        uint256[] memory workIds = new uint256[](2);
        workIds[0] = workId;
        workIds[1] = workIdTwo;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 20;

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        _ashurbanipal.safeBatchTransferFrom(bob, frank, workIds, amounts, "");
    }

    function testBatchTransferBlacklistedRecipient() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = _nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            bob
        );

        uint256[] memory workIds = new uint256[](2);
        workIds[0] = workId;
        workIds[1] = workIdTwo;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 20;

        vm.prank(bob);
        _nabu.updateBlacklist(workIdTwo, frank, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        _ashurbanipal.safeBatchTransferFrom(alice, frank, workIds, amounts, "");
    }

    function testTransferBanLifted() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        vm.prank(alice);
        _nabu.updateBlacklist(workId, bob, false);

        assertEq(_ashurbanipal.balanceOf(bob, workId), 1_000, "Bob pass balance before mismatch");
        assertEq(_ashurbanipal.balanceOf(charlie, workId), 2_000, "Charlie pass balance before mismatch");

        vm.prank(bob);
        _ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        assertEq(_ashurbanipal.balanceOf(bob, workId), 995, "Bob pass balance after mismatch");
        assertEq(_ashurbanipal.balanceOf(charlie, workId), 2_005, "Charlie pass balance after mismatch");
    }

    function testUpdateNabuAddress() public {
        assertEq(_ashurbanipal.getNabuAddress(), address(_nabu), "Nabu address mismatch");

        _ashurbanipal.updateNabuAddress(address(420));
        assertEq(_ashurbanipal.getNabuAddress(), address(420), "Nabu address mismatch");
    }

    function testUpdateNabuAddressNotOwner() public prank(mallory) {
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
        _ashurbanipal.updateNabuAddress(address(420));
    }
}
