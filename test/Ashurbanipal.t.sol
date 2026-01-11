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

    bytes passageOne = bytes(
        unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad."
    );
    bytes passageOneCompressed = LibZip.flzCompress(passageOne);

    bytes passageOneMalicious = bytes(unicode"¡Soy muy malo y quiero destruir el patrimonio literario de España!");
    bytes passageOneMaliciousCompressed = LibZip.flzCompress(passageOneMalicious);

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

    function distributePasses(uint256 workId) private {
        ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
        ashurbanipal.safeTransferFrom(alice, charlie, workId, 2_000, "");
        ashurbanipal.safeTransferFrom(alice, dave, workId, 500, "");
        ashurbanipal.safeTransferFrom(alice, mallory, workId, 666, "");
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
        ashurbanipal.updateUri(workId, "https://hmmm.cool/{id}.json");
    }

    function testGetNabuAddress() public {
        address nabuAddress = ashurbanipal.nabuAddress();
        assertEq(nabuAddress, address(nabu), "Nabu address mismatch");
    }

    function testMintNotNabu() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(NotNabu.selector));
        ashurbanipal.mint(mallory, workId, 100, "https://yes.wowee/{id}.json");
    }

    function testTransfer() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(ashurbanipal.balanceOf(bob, workId), 1_000, "Bob pass balance before mismatch");
        assertEq(ashurbanipal.balanceOf(charlie, workId), 2_000, "Charlie pass balance before mismatch");

        vm.prank(bob);
        ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        assertEq(ashurbanipal.balanceOf(bob, workId), 995, "Bob pass balance after mismatch");
        assertEq(ashurbanipal.balanceOf(charlie, workId), 2_005, "Charlie pass balance after mismatch");
    }

    function testBatchTransfer() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = nabu.createWork(
            "William Shakespeare",
            "Arbitrary informative metadata",
            "Hamlet",
            20_000,
            "https://baz.qux/{id}.json",
            50,
            bob
        );

        assertEq(ashurbanipal.balanceOf(bob, workId), 1_000, "Bob work one pass balance before mismatch");
        assertEq(ashurbanipal.balanceOf(bob, workIdTwo), 50, "Bob work two pass balance before mismatch");
        assertEq(ashurbanipal.balanceOf(frank, workId), 0, "Frank work one pass balance before mismatch");
        assertEq(ashurbanipal.balanceOf(frank, workIdTwo), 0, "Frank work two pass balance before mismatch");

        uint256[] memory workIds = new uint256[](2);
        workIds[0] = workId;
        workIds[1] = workIdTwo;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 20;

        vm.prank(bob);
        ashurbanipal.safeBatchTransferFrom(bob, frank, workIds, amounts, "");

        assertEq(ashurbanipal.balanceOf(bob, workId), 999, "Bob work one pass balance after mismatch");
        assertEq(ashurbanipal.balanceOf(bob, workIdTwo), 30, "Bob work two pass balance after mismatch");
        assertEq(ashurbanipal.balanceOf(frank, workId), 1, "Frank work one pass balance after mismatch");
        assertEq(ashurbanipal.balanceOf(frank, workIdTwo), 20, "Frank work two pass balance after mismatch");
    }

    function testTransferBlacklistedSender() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");
    }

    function testTransferBlacklistedRecipient() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        nabu.updateBlacklist(workId, charlie, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");
    }

    function testBatchTransferBlacklistedSender() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = nabu.createWork(
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
        nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        ashurbanipal.safeBatchTransferFrom(bob, frank, workIds, amounts, "");
    }

    function testBatchTransferBlacklistedRecipient() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        uint256 workIdTwo = nabu.createWork(
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
        nabu.updateBlacklist(workIdTwo, frank, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        ashurbanipal.safeBatchTransferFrom(alice, frank, workIds, amounts, "");
    }

    function testTransferBanLifted() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        nabu.updateBlacklist(workId, bob, true);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IsFrozen.selector));
        ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        vm.prank(alice);
        nabu.updateBlacklist(workId, bob, false);

        assertEq(ashurbanipal.balanceOf(bob, workId), 1_000, "Bob pass balance before mismatch");
        assertEq(ashurbanipal.balanceOf(charlie, workId), 2_000, "Charlie pass balance before mismatch");

        vm.prank(bob);
        ashurbanipal.safeTransferFrom(bob, charlie, workId, 5, "");

        assertEq(ashurbanipal.balanceOf(bob, workId), 995, "Bob pass balance after mismatch");
        assertEq(ashurbanipal.balanceOf(charlie, workId), 2_005, "Charlie pass balance after mismatch");
    }

    function testUpdateNabuAddress() public {
        assertEq(ashurbanipal.nabuAddress(), address(nabu), "Nabu address mismatch");

        ashurbanipal.updateNabuAddress(address(420));
        assertEq(ashurbanipal.nabuAddress(), address(420), "Nabu address mismatch");
    }

    function testFailUpdateNabuAddressNotOwner() public prank(mallory) {
        ashurbanipal.updateNabuAddress(address(420));
    }
}
