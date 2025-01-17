// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol"; // TODO: remove
import "@solady/src/auth/Ownable.sol";
import "./Ashurbanipal.sol";

uint256 constant ONE_DAY = 7_200;
uint256 constant SEVEN_DAYS = 50_400;
uint256 constant THIRTY_DAYS = 216_000;

error CannotDoubleConfirmPassage();
error InvalidPassageId();
error NoPass();
error NotWorkAdmin(address workAdmin);
error PassageAlreadyFinalized();
error TooLate(uint256 expiredAt);
error TooSoonToAssignContent(uint256 canAssignAfter);

struct Passage {
    // the compressed content of the passage (TODO: compression algorithm)
    bytes content;
    // who performed the initial assignment?
    address byZero;
    // who performed the first confirmation?
    address byOne;
    // the block at which `count` last reset or incremented
    uint256 at;
    // how many times the passage's content has been confirmed. assigning new or different content to the passage
    // resets `count` to 0. assigning the same content increments `count`. a passage is considered finalized when
    // `count` reaches 2, at which point only the work's `admin` can assign it new or different content (reseting
    // `count` to 0 in the process)
    uint8 count;
}

struct Work {
    // who wrote the work?
    string author;
    // arbitrary metadata. whatever you want to add
    string metadata;
    // the title of the work
    string title;
    // who initialized the work? `admin` sets `totalPassagesCount` and has the ability to override a finalized passage
    // by resetting `confirmations.count` to 0
    address admin;
    // the total number of passages in the work
    uint256 totalPassagesCount;
    // the block at which the work was created
    uint256 createdAt;
    // metadata uri for the ERC-1155 token id associated with the work (see Ashurbanipal)
    string uri;
}

contract Nabu is Ownable {
    address public ashurbanipalAddress;
    Ashurbanipal ashurbanipal;

    mapping(uint256 => Work) private _works;
    mapping(uint256 => mapping(uint256 => Passage)) private _passages;
    uint256 private worksTip;

    // a work's `admin` has 30 days to make updates to the work's `title`, `author`, etc.
    modifier notTooLate(uint256 workId) {
        uint256 expiredAt = _works[workId].createdAt + THIRTY_DAYS;
        // note the buffer: they can still make changes in the `expiredAt` block itself
        require(block.number < expiredAt + 1, TooLate(expiredAt));
        _;
    }

    modifier onlyWorkAdmin(uint256 workId) {
        address admin = _works[workId].admin;
        require(msg.sender == admin, NotWorkAdmin(admin));
        _;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function adminAssignPassageContent(uint256 workId, uint256 passageId, bytes memory content)
        public
        onlyWorkAdmin(workId)
        returns (uint8)
    {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        _passages[workId][passageId].at = block.number;
        _passages[workId][passageId].byZero = msg.sender;
        _passages[workId][passageId].byOne = address(0);
        _passages[workId][passageId].content = content;
        _passages[workId][passageId].count = 0;

        return 0; // passage.count
    }

    function assignPassageContent(uint256 workId, uint256 passageId, bytes memory content) public returns (uint8) {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        Passage memory passage = _passages[workId][passageId];
        uint8 count = passage.count;

        if (count == 2) {
            revert PassageAlreadyFinalized();
        }

        uint256 canAssignAfter;

        if (count == 0 && keccak256(passage.content) != keccak256(bytes(""))) {
            canAssignAfter = passage.at + ONE_DAY;
        } else if (count == 1) {
            canAssignAfter = passage.at + SEVEN_DAYS;
        }

        if (block.number < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        if (ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }

        if (keccak256(passage.content) == keccak256(content)) {
            _passages[workId][passageId].count = count + 1;

            if (count == 0) {
                _passages[workId][passageId].byOne = msg.sender;
            }
        } else {
            _passages[workId][passageId].byZero = msg.sender;
            _passages[workId][passageId].content = content;
            _passages[workId][passageId].count = 0;
        }

        _passages[workId][passageId].at = block.number;
        return _passages[workId][passageId].count;
    }

    function confirmPassageContent(uint256 workId, uint256 passageId) public returns (uint8) {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        Passage memory passage = _passages[workId][passageId];
        uint8 count = passage.count;

        if (count == 2) {
            revert PassageAlreadyFinalized();
        }

        uint256 canAssignAfter;

        if (count == 0) {
            canAssignAfter = passage.at + ONE_DAY;
        } else if (count == 1) {
            canAssignAfter = passage.at + SEVEN_DAYS;
        }

        if (block.number < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        if (ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }

        _passages[workId][passageId].count = count + 1;

        if (count == 0) {
            _passages[workId][passageId].byOne = msg.sender;
        }

        _passages[workId][passageId].at = block.number;
        return _passages[workId][passageId].count;
    }

    function createWork(
        string memory author,
        string memory metadata,
        string memory title,
        uint256 totalPassagesCount,
        string memory uri,
        uint256 supply
    ) public returns (uint256) {
        worksTip += 1;
        _works[worksTip] = Work(author, metadata, title, msg.sender, totalPassagesCount, block.number, uri);
        ashurbanipal.mint(msg.sender, worksTip, supply, uri);
        return worksTip;
    }

    function getPassage(uint256 workId, uint256 passageId) public view returns (Passage memory) {
        return _passages[workId][passageId];
    }

    function getPassageContent(uint256 workId, uint256 passageId) public view returns (bytes memory) {
        return _passages[workId][passageId].content;
    }

    function getWork(uint256 workId) public view returns (Work memory) {
        return _works[workId];
    }

    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        ashurbanipalAddress = newAshurbanipalAddress;
        ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    function updateWorkAdmin(uint256 workId, address newAdmin) public onlyWorkAdmin(workId) {
        _works[workId].admin = newAdmin;
    }

    function updateWorkAuthor(uint256 workId, string memory newAuthor)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].author = newAuthor;
    }

    function updateWorkMetadata(uint256 workId, string memory newMetadata)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].metadata = newMetadata;
    }

    function updateWorkTitle(uint256 workId, string memory newTitle) public notTooLate(workId) onlyWorkAdmin(workId) {
        _works[workId].title = newTitle;
    }

    function updateWorkTotalPassagesCount(uint256 workId, uint256 newTotalPassagesCount)
        public
        notTooLate(workId)
        onlyWorkAdmin(workId)
    {
        _works[workId].totalPassagesCount = newTotalPassagesCount;
    }

    function updateWorkUri(uint256 workId, string memory newUri) public notTooLate(workId) onlyWorkAdmin(workId) {
        ashurbanipal.updateUri(workId, newUri);
        _works[workId].uri = newUri;
    }
}
