// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "./Ashurbanipal.sol";

uint256 constant ONE_DAY = 7_200;
uint256 constant SEVEN_DAYS = 50_400;
uint256 constant THIRTY_DAYS = 216_000;

error CannotDoubleConfirmPassage();
error InvalidPassageId();
error NoPass();
error NotWorkAdmin(address workAdmin);
error PassageAlreadyFinalized();
error PassageTooLarge();
error TooLate(uint256 expiredAt);
error TooSoonToAssignContent(uint256 canAssignAfter);

struct Passage {
    // the address pointer for the compressed content of the passage (TODO: compression algorithm)
    address content;
    // who performed the initial assignment?
    address byZero;
    // who performed the first confirmation?
    address byOne;
    // who performed the second confirmation (finalized the passage)?
    address byTwo;
    // the block at which the last assignment or confirmation was performed
    uint256 at;
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
    {
        // SSTORE2 max size
        if (content.length > 24576) {
            revert PassageTooLarge();
        }

        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        _passages[workId][passageId].content = SSTORE2.write(content);
        _passages[workId][passageId].byZero = msg.sender;
        _passages[workId][passageId].byOne = address(0);
        _passages[workId][passageId].byTwo = address(0);
        _passages[workId][passageId].at = block.number;
    }

    function assignPassageContent(uint256 workId, uint256 passageId, bytes memory content) public {
        // SSTORE2 max size
        if (content.length > 24576) {
            revert PassageTooLarge();
        }

        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        Passage memory passage = _passages[workId][passageId];

        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        uint256 canAssignAfter;

        if (passage.byOne != address(0)) {
            canAssignAfter = passage.at + SEVEN_DAYS;
        } else if (passage.byZero != address(0)) {
            canAssignAfter = passage.at + ONE_DAY;
        }

        if (block.number < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        if (ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }


        if (passage.content != address(0)) {
            if (keccak256(SSTORE2.read(passage.content)) == keccak256(content)) {
                if (passage.byOne != address(0)) {
                    _passages[workId][passageId].byTwo = msg.sender;
                } else {
                    _passages[workId][passageId].byOne = msg.sender;
                }
            }
            else {
                _passages[workId][passageId].content = SSTORE2.write(content);
                _passages[workId][passageId].byZero = msg.sender;
                _passages[workId][passageId].byOne = address(0);
            }
        } else {
            _passages[workId][passageId].content = SSTORE2.write(content);
            _passages[workId][passageId].byZero = msg.sender;
        }

        _passages[workId][passageId].at = block.number;
    }

    function confirmPassageContent(uint256 workId, uint256 passageId) public {
        Work storage work = _works[workId];

        if (passageId > work.totalPassagesCount) {
            revert InvalidPassageId();
        }

        Passage memory passage = _passages[workId][passageId];

        if (passage.byTwo != address(0)) {
            revert PassageAlreadyFinalized();
        }

        if (passage.byZero == msg.sender || passage.byOne == msg.sender) {
            revert CannotDoubleConfirmPassage();
        }

        uint256 canAssignAfter;

        if (passage.byOne != address(0)) {
            canAssignAfter = passage.at + SEVEN_DAYS;
        } else {
            canAssignAfter = passage.at + ONE_DAY;
        }

        if (block.number < canAssignAfter) {
            revert TooSoonToAssignContent(canAssignAfter);
        }

        if (ashurbanipal.balanceOf(msg.sender, workId) == 0) {
            revert NoPass();
        }

        if (passage.byOne != address(0)) {
            _passages[workId][passageId].byTwo = msg.sender;
        } else {
            _passages[workId][passageId].byOne = msg.sender;
        }

        _passages[workId][passageId].at = block.number;
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
        return SSTORE2.read(_passages[workId][passageId].content);
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
