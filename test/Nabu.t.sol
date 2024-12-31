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
}

contract NabuTest is Test {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    Ashurbanipal public ashurbanipal;
    Nabu public nabu;

    address adminOne = address(1);

    function setUp() public {
        nabu = new Nabu();
        address nabuAddress = address(nabu);
        ashurbanipal = new Ashurbanipal(nabuAddress);
        nabu.updateAshurbanipalAddress(address(ashurbanipal));
    }

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

    function testCreateWork() public {
        cheats.prank(adminOne);
        uint256 workId = createWork();

        string memory title = nabu.getWork(workId).title;
        string memory expectedTitle = "Don Quijote";

        Work memory work = nabu.getWork(workId);

        assert(keccak256(bytes(title)) == keccak256(bytes(expectedTitle)));

        string memory author = work.author;
        string memory expectedAuthor = "Miguel de Cervantes";

        assert(keccak256(bytes(author)) == keccak256(bytes(expectedAuthor)));

        string memory metadata = work.metadata;
        string memory expectedMetadata = "Original title: El ingenioso hidalgo don Quijote de la Mancha";

        assert(keccak256(bytes(metadata)) == keccak256(bytes(expectedMetadata)));

        uint256 totalPassagesCount = work.totalPassagesCount;
        uint256 expectedTotalPassagesCount = 1_000_000;

        assert(totalPassagesCount == expectedTotalPassagesCount);

        string memory uri = ashurbanipal.uri(workId);
        string memory expectedUri = "https://foo.bar/{id}.json";

        assert(keccak256(bytes(uri)) == keccak256(bytes(expectedUri)));

        uint256 adminPassBalance = ashurbanipal.balanceOf(adminOne, workId);
        uint256 expectedAdminPassBalance = 10_000;

        assert(adminPassBalance == expectedAdminPassBalance);
    }
}
