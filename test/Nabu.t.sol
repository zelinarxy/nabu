// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "@solady/src/utils/LibZip.sol";
import "../src/Ashurbanipal.sol";
import "../src/Nabu.sol";

interface CheatCodes {
    function expectRevert(bytes calldata) external;

    function prank(address) external;

    function roll(uint256) external;

    function startPrank(address, address) external;

    function stopPrank() external;
}

contract NabuTest is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    Ashurbanipal public ashurbanipal;
    Nabu public nabu;

    address alice = address(1);
    address bob = address(2);
    address charlie = address(3);
    address dave = address(4);
    address mallory = address(5);

    function setUp() public {
        cheats.roll(0);
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

    function createWorkAndDistributePassesAsAlice() private returns (uint256) {
        cheats.startPrank(alice, alice);
        uint256 workId = createWork();
        distributePasses(workId);
        cheats.stopPrank();
        return workId;
    }

    function testCreateWork() public {
        cheats.prank(alice);
        uint256 workId = createWork();
        assert(workId == 1);

        Work memory work = nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "Miguel de Cervantes";
        assert(keccak256(bytes(author)) == keccak256(bytes(expectedAuthor)));

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Original title: El ingenioso hidalgo don Quijote de la Mancha";
        assert(keccak256(bytes(metadata)) == keccak256(bytes(expectedMetadata)));

        string memory title = nabu.getWork(workId).title;
        string memory expectedTitle = "Don Quijote";
        assert(keccak256(bytes(title)) == keccak256(bytes(expectedTitle)));

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 1_000_000;
        assert(totalPassagesCount == expectedTotalPassagesCount);

        string memory uri = ashurbanipal.uri(workId);
        string memory expectedUri = "https://foo.bar/{id}.json";
        assert(keccak256(bytes(uri)) == keccak256(bytes(expectedUri)));

        uint256 alicePassBalance = ashurbanipal.balanceOf(alice, workId);
        uint256 expectedAlicePassBalance = 10_000;
        assert(alicePassBalance == expectedAlicePassBalance);
    }

    function testCreateSecondWork() public {
        cheats.prank(alice);
        createWork();

        cheats.prank(bob);

        uint256 workId = nabu.createWork(
            "William Shakespeare", "Arbitrary informative metadata", "Hamlet", 20_000, "https://baz.qux/{id}.json", 50
        );

        assert(workId == 2);

        Work memory work = nabu.getWork(workId);

        string memory author = work.author;
        string memory expectedAuthor = "William Shakespeare";
        assert(keccak256(bytes(author)) == keccak256(bytes(expectedAuthor)));

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Arbitrary informative metadata";
        assert(keccak256(bytes(metadata)) == keccak256(bytes(expectedMetadata)));

        string memory title = nabu.getWork(workId).title;
        string memory expectedTitle = "Hamlet";
        assert(keccak256(bytes(title)) == keccak256(bytes(expectedTitle)));

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 20_000;
        assert(totalPassagesCount == expectedTotalPassagesCount);

        string memory uri = ashurbanipal.uri(workId);
        string memory expectedUri = "https://baz.qux/{id}.json";
        assert(keccak256(bytes(uri)) == keccak256(bytes(expectedUri)));

        uint256 bobPassBalance = ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 50;
        assert(bobPassBalance == expectedBobPassBalance);
    }

    function testDistributePasses() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        uint256 endingAlicePassBalance = ashurbanipal.balanceOf(alice, workId);
        uint256 expectedEndingAlicePassBalance = 5_834;
        assert(endingAlicePassBalance == expectedEndingAlicePassBalance);

        uint256 bobPassBalance = ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 1_000;
        assert(bobPassBalance == expectedBobPassBalance);

        uint256 charliePassBalance = ashurbanipal.balanceOf(charlie, workId);
        uint256 expectedCharliePassBalance = 2_000;
        assert(charliePassBalance == expectedCharliePassBalance);

        uint256 davePassBalance = ashurbanipal.balanceOf(dave, workId);
        uint256 expectedDavePassBalance = 500;
        assert(davePassBalance == expectedDavePassBalance);

        uint256 malloryPassBalance = ashurbanipal.balanceOf(mallory, workId);
        uint256 expectedMalloryPassBalance = 666;
        assert(malloryPassBalance == expectedMalloryPassBalance);
    }

    function testWritePassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(content)) == keccak256(passageOne));

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == 0);
        assert(passage.byZero == bob);
        assert(passage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 0);
    }

    function testWritePassageInvalidPassageId() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(InvalidPassageId.selector));
        nabu.assignPassageContent(workId, 1_000_001, passageOneCompressed);
    }

    function testWritePassagePermissionDenied() public {
        cheats.prank(alice);
        uint256 workId = createWork();

        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(PermissionDenied.selector));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testManuallyConfirmPassageOnce() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == ONE_DAY);
        assert(passage.byZero == bob);
        assert(passage.byOne == charlie);
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 1);
    }

    function testManuallyConfirmPassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.prank(dave);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == ONE_DAY + SEVEN_DAYS);
        assert(passage.byZero == bob);
        assert(passage.byOne == charlie);
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 2);
    }

    // TODO: this but for second confirmation
    function testConfirmPassageCannotDoubleConfirm() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);
    }

    // TODO: this but for second confirmation
    function testManuallyConfirmPassageCannotDoubleConfirm() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.expectRevert(abi.encodeWithSelector(CannotDoubleConfirmPassage.selector));
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testWritePassageAlreadyFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.prank(dave);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.prank(mallory);
        cheats.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);
    }

    function testConfirmPassageOnce() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == ONE_DAY);
        assert(passage.byZero == bob);
        assert(passage.byOne == charlie);
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 1);
    }

    function testConfirmPassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.prank(dave);
        nabu.confirmPassageContent(workId, 1);

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == ONE_DAY + SEVEN_DAYS);
        assert(passage.byZero == bob);
        assert(passage.byOne == charlie);
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 2);
    }

    function testConfirmPassageAlreadyFinalized() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.prank(dave);
        nabu.confirmPassageContent(workId, 1);

        cheats.prank(mallory);
        cheats.expectRevert(abi.encodeWithSelector(PassageAlreadyFinalized.selector));
        nabu.confirmPassageContent(workId, 1);
    }

    function testOverwritePassage() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(mallory);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        bytes memory maliciousContent = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(maliciousContent)) == keccak256(passageOneMalicious));

        Passage memory maliciousPassage = nabu.getPassage(workId, 1);
        assert(maliciousPassage.at == 0);
        assert(maliciousPassage.byZero == mallory);
        assert(maliciousPassage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(maliciousPassage.content)) == keccak256(passageOneMalicious));
        assert(maliciousPassage.count == 0);

        cheats.roll(ONE_DAY);
        cheats.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(content)) == keccak256(passageOne));

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == ONE_DAY);
        assert(passage.byZero == alice);
        assert(passage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 0);
    }

    function testOverwritePassageTwice() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(content)) == keccak256(passageOne));

        Passage memory passage = nabu.getPassage(workId, 1);
        assert(passage.at == 0);
        assert(passage.byZero == alice);
        assert(passage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(passage.content)) == keccak256(passageOne));
        assert(passage.count == 0);

        cheats.roll(ONE_DAY);
        cheats.prank(mallory);
        nabu.assignPassageContent(workId, 1, passageOneMaliciousCompressed);

        bytes memory maliciousContent = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(maliciousContent)) == keccak256(passageOneMalicious));

        Passage memory maliciousPassage = nabu.getPassage(workId, 1);
        assert(maliciousPassage.at == ONE_DAY);
        assert(maliciousPassage.byZero == mallory);
        assert(maliciousPassage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(maliciousPassage.content)) == keccak256(passageOneMalicious));
        assert(maliciousPassage.count == 0);

        cheats.roll(ONE_DAY + SEVEN_DAYS);
        cheats.prank(alice);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory restoredContent = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(restoredContent)) == keccak256(passageOne));

        Passage memory restoredPassage = nabu.getPassage(workId, 1);
        assert(restoredPassage.at == ONE_DAY + SEVEN_DAYS);
        assert(restoredPassage.byZero == alice);
        assert(restoredPassage.byOne == address(0));
        assert(keccak256(LibZip.flzDecompress(restoredPassage.content)) == keccak256(passageOne));
        assert(restoredPassage.count == 0);
    }

    function testUpdateAshurbanipalAddress() public {
        assert(nabu.ashurbanipalAddress() == address(ashurbanipal));

        nabu.updateAshurbanipalAddress(address(69));
        assert(nabu.ashurbanipalAddress() == address(69));
    }

    function testFailUpdateAshurbanipalAddressNotOwner() public {
        cheats.prank(mallory);
        nabu.updateAshurbanipalAddress(address(69));
    }

    function testUpdateWorkAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(nabu.getWork(workId).admin == alice);

        cheats.prank(alice);
        nabu.updateWorkAdmin(workId, bob);
        assert(nabu.getWork(workId).admin == bob);
    }

    function testUpdateWorkAdminNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkAdmin(workId, bob);
    }

    function testUpdateWorkAuthor() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(keccak256(bytes(nabu.getWork(workId).author)) == keccak256(bytes("Miguel de Cervantes")));

        cheats.prank(alice);
        nabu.updateWorkAuthor(workId, "Mickey C");
        assert(keccak256(bytes(nabu.getWork(workId).author)) == keccak256(bytes("Mickey C")));
    }

    function testUpdateWorkAuthorNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function testUpdateWorkAuthorTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.roll(THIRTY_DAYS + 1);
        cheats.prank(alice);
        cheats.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkAuthor(workId, "Mickey C");
    }

    function testUpdateWorkMetadata() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(
            keccak256(bytes(nabu.getWork(workId).metadata))
                == keccak256(bytes("Original title: El ingenioso hidalgo don Quijote de la Mancha"))
        );

        cheats.prank(alice);
        nabu.updateWorkMetadata(workId, "New metadata");
        assert(keccak256(bytes(nabu.getWork(workId).metadata)) == keccak256(bytes("New metadata")));
    }

    function testUpdateWorkMetadataNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkMetadata(workId, "New metadata");
    }

    function testUpdateWorkMetadataTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.roll(THIRTY_DAYS + 1);
        cheats.prank(alice);
        cheats.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkMetadata(workId, "New metadata");
    }

    function testUpdateWorkUri() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(keccak256(bytes(nabu.getWork(workId).uri)) == keccak256(bytes("https://foo.bar/{id}.json")));
        assert(keccak256(bytes(ashurbanipal.uri(workId))) == keccak256(bytes("https://foo.bar/{id}.json")));

        cheats.prank(alice);
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
        assert(keccak256(bytes(nabu.getWork(workId).uri)) == keccak256(bytes("https://lol.lmao/{id}.json")));
        assert(keccak256(bytes(ashurbanipal.uri(workId))) == keccak256(bytes("https://lol.lmao/{id}.json")));
    }

    function testUpdateWorkUriNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function testUpdateWorkUriTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.roll(THIRTY_DAYS + 1);
        cheats.prank(alice);
        cheats.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkUri(workId, "https://lol.lmao/{id}.json");
    }

    function testUpdateWorkTitle() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(keccak256(bytes(nabu.getWork(workId).title)) == keccak256(bytes("Don Quijote")));

        cheats.prank(alice);
        nabu.updateWorkTitle(workId, "Donny Q");
        assert(keccak256(bytes(nabu.getWork(workId).title)) == keccak256(bytes("Donny Q")));
    }

    function testUpdateWorkTitleNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkTitle(workId, "Donny Q");
    }

    function testUpdateWorkTitleTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.roll(THIRTY_DAYS + 1);
        cheats.prank(alice);
        cheats.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkTitle(workId, "Donny Q");
    }

    function testUpdateWorkTotalPassagesCount() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        assert(nabu.getWork(workId).totalPassagesCount == 1_000_000);

        cheats.prank(alice);
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
        assert(nabu.getWork(workId).totalPassagesCount == 69_000);
    }

    function testUpdateWorkTotalPassagesCountNotAdmin() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.prank(bob);
        cheats.expectRevert(abi.encodeWithSelector(NotWorkAdmin.selector, alice));
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function testUpdateWorkTotalPassagesCountTooLate() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();
        cheats.roll(THIRTY_DAYS + 1);
        cheats.prank(alice);
        cheats.expectRevert(abi.encodeWithSelector(TooLate.selector, THIRTY_DAYS));
        nabu.updateWorkTotalPassagesCount(workId, 69_000);
    }

    function testConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY - 1);
        cheats.prank(charlie);
        cheats.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY));
        nabu.confirmPassageContent(workId, 1);
    }

    function testManuallyConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY - 1);
        cheats.prank(charlie);
        cheats.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    function testDoubleConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.confirmPassageContent(workId, 1);

        cheats.roll(ONE_DAY + SEVEN_DAYS - 1);
        cheats.prank(dave);
        cheats.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY + SEVEN_DAYS));
        nabu.confirmPassageContent(workId, 1);
    }

    function testManuallyDoubleConfirmPassageTooSoonToAssignContent() public {
        uint256 workId = createWorkAndDistributePassesAsAlice();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY);
        cheats.prank(charlie);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        cheats.roll(ONE_DAY + SEVEN_DAYS - 1);
        cheats.prank(dave);
        cheats.expectRevert(abi.encodeWithSelector(TooSoonToAssignContent.selector, ONE_DAY + SEVEN_DAYS));
        nabu.assignPassageContent(workId, 1, passageOneCompressed);
    }

    // TODO: test admin override of finalized block
    // TODO: test admin switch - old admin can't update
    // TODO: test admin switch - new admin can update
}
