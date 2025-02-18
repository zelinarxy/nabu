// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@solady/src/tokens/ERC1155.sol";
import "@solady/src/auth/Ownable.sol";

error IsFrozen();
error NotNabu();

contract Ashurbanipal is ERC1155, Ownable {
    address private _nabuAddress;

    mapping(uint256 => string) private _uris;
    mapping(uint256 => mapping(address => bool)) private _freezelist;

    modifier onlyNabu() {
        require(msg.sender == _nabuAddress, NotNabu());
        _;
    }

    constructor(address initialNabuAddress) ERC1155() {
        _nabuAddress = initialNabuAddress;
    }

    function mint(address account, uint256 workId, uint256 supply, string memory workUri) public onlyNabu {
        _mint(account, workId, supply, "");
        _uris[workId] = workUri;
    }

    function nabuAddress() public returns (address) {
        return _nabuAddress;
    }

    function updateFreezelist(uint256 workId, address user, bool shouldFreeze) public onlyNabu {
        _freezelist[workId][user] = shouldFreeze;
    }

    function updateUri(uint256 workId, string memory newUri) public onlyNabu {
        _uris[workId] = newUri;
    }

    function uri(uint256 workId) public view override returns (string memory) {
        return _uris[workId];
    }

    function _useBeforeTokenTransfer() internal view override returns (bool) {
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        // TODO: gas gimmicks
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];

            if (_freezelist[id][from] || _freezelist[id][to]) {
                revert IsFrozen();
            }
        }
    }
}
