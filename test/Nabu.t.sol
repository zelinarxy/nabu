// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {LibZip} from "@solady/src/utils/LibZip.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "../src/Ashurbanipal.sol";
import "../src/Nabu.sol";

contract NabuTest is Test {
    Ashurbanipal public ashurbanipal;
    Nabu public nabu;

    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address charlie = makeAddr("Charlie");
    address dave = makeAddr("Dave");
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
    }

    bytes passageOne = bytes(
        unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad."
    );
    bytes passageOneCompressed = LibZip.flzCompress(passageOne);

    bytes passageOneMalicious = bytes(unicode"¡Soy muy malo y quiero destruir el patrimonio literario de España!");
    bytes passageOneMaliciousCompressed = LibZip.flzCompress(passageOneMalicious);

    function createWork() private returns (uint256) {
        uint256 workId = nabu.createWork(
            "Miguel de Cervantes",
            "Original title: El ingenioso hidalgo don Quijote de la Mancha",
            "Don Quijote",
            1_000_000,
            "https://foo.bar/{id}.json",
            10_000
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
        uint256 workId = createWork();
        distributePasses(workId);
        return workId;
    }

    function testCreateWork() public {
        vm.prank(alice);
        uint256 workId = createWork();
        assertEq(workId, 1, "Work ID mismatch");

        Work memory work = nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "Miguel de Cervantes";
        assertEq(author, expectedAuthor, "Author mismatch");

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Original title: El ingenioso hidalgo don Quijote de la Mancha";
        assertEq(metadata, expectedMetadata, "Metadata mismatch");

        string memory title = nabu.getWork(workId).title;
        string memory expectedTitle = "Don Quijote";
        assertEq(title, expectedTitle, "Title mismatch");

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 1_000_000;
        assertEq(totalPassagesCount, expectedTotalPassagesCount, "Total passages count mismatch");

        string memory uri = ashurbanipal.uri(workId);
        string memory expectedUri = "https://foo.bar/{id}.json";
        assertEq(uri, expectedUri, "URI mismatch");

        uint256 alicePassBalance = ashurbanipal.balanceOf(alice, workId);
        uint256 expectedAlicePassBalance = 10_000;
        assertEq(alicePassBalance, expectedAlicePassBalance, "Alice pass balance mismatch");
    }

    function testCreateSecondWork() public {
        vm.prank(alice);
        createWork();

        vm.prank(bob);
        uint256 workId = nabu.createWork(
            "William Shakespeare", "Arbitrary informative metadata", "Hamlet", 20_000, "https://baz.qux/{id}.json", 50
        );
        assertEq(workId, 2, "Work ID mismatch");

        Work memory work = nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "William Shakespeare";
        assertEq(author, expectedAuthor, "Author mismatch");

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Arbitrary informative metadata";
        assertEq(metadata, expectedMetadata, "Metadata mismatch");

        string memory title = nabu.getWork(workId).title;
        string memory expectedTitle = "Hamlet";
        assertEq(title, expectedTitle, "Title mismatch");

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 20_000;
        assertEq(totalPassagesCount, expectedTotalPassagesCount, "Total passages count mismatch");

        string memory uri = ashurbanipal.uri(workId);
        string memory expectedUri = "https://baz.qux/{id}.json";
        assertEq(uri, expectedUri, "URI mismatch");

        uint256 bobPassBalance = ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 50;
        assertEq(bobPassBalance, expectedBobPassBalance, "Bob pass balance mismatch");
    }

    function testDistributePasses() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        uint256 endingAlicePassBalance = ashurbanipal.balanceOf(alice, workId);
        uint256 expectedEndingAlicePassBalance = 5_834;
        assertEq(endingAlicePassBalance, expectedEndingAlicePassBalance, "Ending Alice pass balance mismatch");

        uint256 bobPassBalance = ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 1_000;
        assertEq(bobPassBalance, expectedBobPassBalance, "Bob pass balance mismatch");

        uint256 charliePassBalance = ashurbanipal.balanceOf(charlie, workId);
        uint256 expectedCharliePassBalance = 2_000;
        assertEq(charliePassBalance, expectedCharliePassBalance, "Charlie pass balance mismatch");

        uint256 davePassBalance = ashurbanipal.balanceOf(dave, workId);
        uint256 expectedDavePassBalance = 500;
        assertEq(davePassBalance, expectedDavePassBalance, "Dave pass balance mismatch");

        uint256 malloryPassBalance = ashurbanipal.balanceOf(mallory, workId);
        uint256 expectedMalloryPassBalance = 666;
        assertEq(malloryPassBalance, expectedMalloryPassBalance, "Mallory pass balance mismatch");
    }

    function testWritePassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assertEq(keccak256(LibZip.flzDecompress(content)), keccak256(passageOne), "Content mismatch");

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, 0, "Passage.at mismatch");
        assertEq(passage.byZero, bob, "Passage.byZero mismatch");
        assertEq(passage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    function testWritePassageInvalidPassageId() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        nabu.assignPassageContent(workId, 1_000_001, passageOneCompressed);
    }

    function testConfirmPassageNoPass() public {
        vm.startPrank(alice, alice);
        uint256 workId = createWork();
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
        vm.stopPrank();

        vm.roll(ONE_DAY);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NoPass.selector));
        nabu.confirmPassageContent(workId, 1);
    }

    function testWritePassageNoPass() public {
        vm.prank(alice);
        uint256 workId = createWork();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NoPass.selector));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testManuallyConfirmPassageOnce() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, ONE_DAY, "Passage.at mismatch");
        assertEq(passage.byZero, bob, "Passage.byZero mismatch");
        assertEq(passage.byOne, charlie, "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    function testManuallyConfirmPassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, ONE_DAY + SEVEN_DAYS, "Passage.at mismatch");
        assertEq(passage.byZero, bob, "Passage.byZero mismatch");
        assertEq(passage.byOne, charlie, "Passage.byOne mismatch");
        assertEq(passage.byTwo, dave, "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    // TODO: this but for second confirmation
    function testConfirmPassageCannotDoubleConfirm() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);
    }

    // TODO: this but for second confirmation
    function testManuallyConfirmPassageCannotDoubleConfirm() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testWritePassageAlreadyFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);
    }

    function testConfirmPassageOnce() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, ONE_DAY, "Passage.at mismatch");
        assertEq(passage.byZero, bob, "Passage.byZero mismatch");
        assertEq(passage.byOne, charlie, "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    function testConfirmPassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        nabu.confirmPassageContent(workId, 1);

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, ONE_DAY + SEVEN_DAYS, "Passage.at mismatch");
        assertEq(passage.byZero, bob, "Passage.byZero mismatch");
        assertEq(passage.byOne, charlie, "Passage.byOne mismatch");
        assertEq(passage.byTwo, dave, "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    function testConfirmPassageAlreadyFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        nabu.confirmPassageContent(workId, 1);

        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        nabu.confirmPassageContent(workId, 1);
    }

    function testOverwritePassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(mallory);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        bytes memory maliciousContent = nabu.getPassageContent(workId, 1);
        assertEq(
            keccak256(LibZip.flzDecompress(maliciousContent)),
            keccak256(passageOneMalicious),
            "Passage.content mismatch"
        );

        Passage memory maliciousPassage = nabu.getPassage(workId, 1);
        assertEq(maliciousPassage.at, 0, "Passage.at mismatch");
        assertEq(maliciousPassage.byZero, mallory, "Passage.byZero mismatch");
        assertEq(maliciousPassage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(maliciousPassage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(
            keccak256(LibZip.flzDecompress(SSTORE2.read(maliciousPassage.content))),
            keccak256(passageOneMalicious),
            "Passage.content mismatch"
        );

        vm.roll(ONE_DAY);
        vm.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assertEq(keccak256(LibZip.flzDecompress(content)), keccak256(passageOne), "Passage.content mismatch");

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, ONE_DAY, "Passage.at mismatch");
        assertEq(passage.byZero, alice, "Passage.byZero mismatch");
        assertEq(passage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");
    }

    function testOverwritePassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assertEq(keccak256(LibZip.flzDecompress(content)), keccak256(passageOne), "Passage.content mismatch");

        Passage memory passage = nabu.getPassage(workId, 1);
        assertEq(passage.at, 0, "Passage.at mismatch");
        assertEq(passage.byZero, alice, "Passage.byZero mismatch");
        assertEq(passage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(LibZip.flzDecompress(SSTORE2.read(passage.content))), keccak256(passageOne), "Passage.content mismatch");

        vm.roll(ONE_DAY);
        vm.prank(mallory);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        bytes memory maliciousContent = nabu.getPassageContent(workId, 1);
        assertEq(
            keccak256(LibZip.flzDecompress(maliciousContent)),
            keccak256(passageOneMalicious),
            "Passage.content mismatch"
        );

        Passage memory maliciousPassage = nabu.getPassage(workId, 1);
        assertEq(maliciousPassage.at, ONE_DAY, "Passage.at mismatch");
        assertEq(maliciousPassage.byZero, mallory, "Passage.byZero mismatch");
        assertEq(maliciousPassage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(maliciousPassage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(
            keccak256(LibZip.flzDecompress(SSTORE2.read(maliciousPassage.content))),
            keccak256(passageOneMalicious),
            "Passage.content mismatch"
        );

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory restoredContent = nabu.getPassageContent(workId, 1);
        assertEq(keccak256(LibZip.flzDecompress(restoredContent)), keccak256(passageOne), "Passage.content mismatch");

        Passage memory restoredPassage = nabu.getPassage(workId, 1);
        assertEq(restoredPassage.at, ONE_DAY + SEVEN_DAYS, "Passage.at mismatch");
        assertEq(restoredPassage.byZero, alice, "Passage.byZero mismatch");
        assertEq(restoredPassage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(restoredPassage.byTwo, address(0), "Passage.byOne mismatch");
        assertEq(
            keccak256(LibZip.flzDecompress(SSTORE2.read(restoredPassage.content))), keccak256(passageOne), "Passage.content mismatch"
        );
    }

    function testUpdateAshurbanipalAddress() public {
        assertEq(nabu.ashurbanipalAddress(), address(ashurbanipal), "Ashurbanipal address mismatch");

        nabu.updateAshurbanipalAddress(address(69));
        assertEq(nabu.ashurbanipalAddress(), address(69), "Ashurbanipal address mismatch");
    }

    function testFailUpdateAshurbanipalAddressNotOwner() public prank(mallory) {
        nabu.updateAshurbanipalAddress(address(69));
    }

    function testUpdateWorkAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(nabu.getWork(workId).admin, alice, "Work admin mismatch");

        vm.prank(alice);
        nabu.updateWorkAdmin(workId, bob);
        assertEq(nabu.getWork(workId).admin, bob, "Work admin mismatch");
    }

    function testUpdateWorkAdminNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkAdmin(workId, bob);
    }

    function testUpdateWorkAuthor() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(
            keccak256(bytes(nabu.getWork(workId).author)),
            keccak256(bytes("Miguel de Cervantes")),
            "Work author mismatch"
        );

        vm.prank(alice);
        nabu.updateWorkAuthor(workId, "Mickey C");
        assertEq(keccak256(bytes(nabu.getWork(workId).author)), keccak256(bytes("Mickey C")), "Work author mismatch");
    }

    function testUpdateWorkAuthorNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function testUpdateWorkAuthorTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function testUpdateWorkMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(
            keccak256(bytes(nabu.getWork(workId).metadata)),
            keccak256(bytes("Original title: El ingenioso hidalgo don Quijote de la Mancha")),
            "Work metadata mismatch"
        );

        vm.prank(alice);
        nabu.updateWorkMetadata(workId, "New metadata");
        assertEq(
            keccak256(bytes(nabu.getWork(workId).metadata)), keccak256(bytes("New metadata")), "Work metadata mismatch"
        );
    }

    function testUpdateWorkMetadataNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkMetadata(workId, "New metadata");
    }

    function testUpdateWorkMetadataTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkMetadata(workId, "New metadata");
    }

    function testUpdateWorkUri() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(
            keccak256(bytes(nabu.getWork(workId).uri)),
            keccak256(bytes("https://foo.bar/{id}.json")),
            "Work uri mismatch"
        );
        assertEq(
            keccak256(bytes(ashurbanipal.uri(workId))),
            keccak256(bytes("https://foo.bar/{id}.json")),
            "Work uri mismatch"
        );

        vm.prank(alice);
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
        assertEq(
            keccak256(bytes(nabu.getWork(workId).uri)),
            keccak256(bytes("https://lol.lmao/{id}.json")),
            "Work uri mismatch"
        );
        assertEq(
            keccak256(bytes(ashurbanipal.uri(workId))),
            keccak256(bytes("https://lol.lmao/{id}.json")),
            "Work uri mismatch"
        );
    }

    function testUpdateWorkUriNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function testUpdateWorkUriTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function testUpdateWorkTitle() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(keccak256(bytes(nabu.getWork(workId).title)), keccak256(bytes("Don Quijote")), "Work title mismatch");

        vm.prank(alice);
        nabu.updateWorkTitle(workId, "Donny Q");
        assertEq(keccak256(bytes(nabu.getWork(workId).title)), keccak256(bytes("Donny Q")), "Work title mismatch");
    }

    function testUpdateWorkTitleNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkTitle(workId, "Donny Q");
    }

    function testUpdateWorkTitleTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkTitle(workId, "Donny Q");
    }

    function testUpdateWorkTotalPassagesCount() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(nabu.getWork(workId).totalPassagesCount, 1_000_000, "Work total passages count mismatch");

        vm.prank(alice);
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
        assertEq(nabu.getWork(workId).totalPassagesCount, 69_000, "Work total passages count mismatch");
    }

    function testUpdateWorkTotalPassagesCountNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function testUpdateWorkTotalPassagesCountTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.roll(THIRTY_DAYS + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function testConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY - 1);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY));
        nabu.confirmPassageContent(workId, 1);
    }

    function testManuallyConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY - 1);
        vm.prank(charlie);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testDoubleConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        vm.roll(ONE_DAY + SEVEN_DAYS - 1);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY + SEVEN_DAYS));
        nabu.confirmPassageContent(workId, 1);
    }

    function testManuallyDoubleConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        vm.roll(ONE_DAY + SEVEN_DAYS - 1);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY + SEVEN_DAYS));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testAdminOverrideFinalizedBlock() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        vm.roll(ONE_DAY);
        vm.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        vm.roll(ONE_DAY + SEVEN_DAYS);
        vm.prank(dave);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        assertEq(
            keccak256(nabu.getPassageContent(workId, 1)),
            keccak256(passageOneMaliciousCompressed),
            "Passage.content mismatch"
        );

        vm.prank(alice);
        nabu.adminAssignPassageContent(workId, 1, passageOneCompressed);

        Passage memory passage = nabu.getPassage(workId, 1);

        assertEq(passage.at, ONE_DAY + SEVEN_DAYS, "Passage.at mismatch");
        assertEq(passage.byZero, alice, "Passage.byZero mismatch");
        assertEq(passage.byOne, address(0), "Passage.byOne mismatch");
        assertEq(passage.byTwo, address(0), "Passage.byTwo mismatch");
        assertEq(keccak256(SSTORE2.read((passage.content))), keccak256(passageOneCompressed), "Passage.content mismatch");
    }

    function testAdminAssignContentInvalidPassageId() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        nabu.adminAssignPassageContent(workId, 1_000_001, passageOneCompressed);
    }

    function testConfirmPassageInvalidPassageId() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        nabu.confirmPassageContent(workId, 1_000_001);
    }

    function updateWorkAdminOldAdminUnauthorized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(nabu.getWork(workId).admin, alice, "Work admin mismatch");

        vm.startPrank(alice, alice);
        nabu.updateWorkAdmin(workId, bob);
        assertEq(nabu.getWork(workId).admin, bob, "Work admin mismatch");

        vm.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, bob));
        nabu.updateWorkTitle(workId, "Donny Q");
        vm.stopPrank();
    }

    function updateWorkAdminNewAdminCanUpdate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assertEq(nabu.getWork(workId).admin, alice, "Work admin mismatch");

        vm.prank(alice);
        nabu.updateWorkAdmin(workId, bob);
        assertEq(nabu.getWork(workId).admin, bob, "Work admin mismatch");

        assertEq(keccak256(bytes(nabu.getWork(workId).title)), keccak256(bytes("Don Quijote")), "Work title mismatch");

        vm.prank(bob);
        nabu.updateWorkTitle(workId, "Donny Q");
        assertEq(keccak256(bytes(nabu.getWork(workId).title)), keccak256(bytes("Donny Q")), "Work title mismatch");
    }

    function testUpdateAshurbanipalUriNotNabu() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(NotNabu.selector));
        ashurbanipal.updateUri(workId, "https://hmmm.cool/{id}.json");
    }

    function testAshurbanipalGetNabuAddress() public {
        address nabuAddress = ashurbanipal.nabuAddress();
        assertEq(nabuAddress, address(nabu), "Nabu address mismatch");
    }

    function testAshurbanipalMintNotNabu() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        vm.prank(mallory);
        vm.expectRevert(abi.encodeWithSelector(NotNabu.selector));
        ashurbanipal.mint(mallory, workId, 100, "https://yes.wowee/{id}.json");
    }
}
