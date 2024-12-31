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

    function setUp() public {
        cheats.roll(21_000_000);
        nabu = new Nabu();
        address nabuAddress = address(nabu);
        ashurbanipal = new Ashurbanipal(nabuAddress);
        nabu.updateAshurbanipalAddress(address(ashurbanipal));
    }

    bytes passageOne = bytes(unicode"En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque, por conjeturas verosímiles, se deja entender que se llamaba Quejana. Pero esto importa poco a nuestro cuento; basta que en la narración dél no se salga un punto de la verdad.");

    bytes passageOneCompressed = LibZip.flzCompress(passageOne);

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

    // alice sends 1k passes to bob
    function distributePasses(uint256 workId) private {
        ashurbanipal.safeTransferFrom(alice, bob, workId, 1_000, "");
    }

    function testCreateWork() public {
        cheats.prank(alice);
        uint256 workId = createWork();
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

    function testDistributePasses() public {
        cheats.startPrank(alice, alice);
        uint256 workId = createWork();

        distributePasses(workId);

        uint256 endingAlicePassBalance = ashurbanipal.balanceOf(alice, workId);
        uint256 expectedEndingAlicePassBalance = 9_000;
        assert(endingAlicePassBalance == expectedEndingAlicePassBalance);

        uint256 bobPassBalance = ashurbanipal.balanceOf(bob, workId);
        uint256 expectedBobPassBalance = 1_000;
        assert(bobPassBalance == expectedBobPassBalance);

        cheats.stopPrank();
    }

    function testWritePassage() public {
        cheats.startPrank(alice, alice);
        uint256 workId = createWork();
        distributePasses(workId);
        cheats.stopPrank();

        cheats.prank(bob);
        nabu.assignPassageContent(workId, 1, passageOneCompressed);

        bytes memory content = nabu.getPassageContent(workId, 1);
        assert(keccak256(LibZip.flzDecompress(content)) == keccak256(passageOne));
    }
}
