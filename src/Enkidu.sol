// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {ERC20} from "@solady/src/tokens/ERC20.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {Receiver} from "@solady/src/accounts/Receiver.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";
import "./Ashurbanipal.sol";

// TODO: notices etc

/// @dev The id the user is trying to mint is inactive
error Inactive();
/// @dev The value of the transaction is too low to successfully mint
error InsufficientFunds();
/// @dev The attempted mint puts the user over the per-address limit on total mints per id
error OverLimit();
/// @dev Can't mint zero passes
error ZeroCount();

/**
 * @dev Owners of a number of Remilia assets are whitelisted: they can mint up to a certain number of passes per id
 * for free. The same is the case for owners of Humbaba NFTs, assuming a Humbaba contract has been deployed and
 * associated with this Enkidu instance. To save gas, it's the responsibility of the caller of the `mint` function to
 * be aware of the user's portfolio and specify the asset, if any, that grants them whitelisted status. If none, the
 * caller can specify `None` and avoid a series of balance checks. If the caller is uncertain, `Any` will check all
 * eligible assets. If an asset is specified but the balance check comes back negative, the function will check all
 * other assets, on the assumption that the user expects to be whitelisted, but supplied the wrong argument for some
 * reason.
 */
enum WhitelistedToken {
    Any, // 0
    None, // 1
    Cult, // 2
    Aura, // 3
    Cigawrette, // 4
    Milady, // 5
    Pixelady, // 6
    Radbro, // 7
    Remilio, // 8
    Schizoposter, // 9
    Humbaba // 10

}

/// @dev Whitelisted token: Cult
address constant CULT = 0x0000000000c5dc95539589fbD24BE07c6C14eCa4;

/// @dev Whitelisted NFT: MiladyAura
address constant AURA = 0x2fC722C1c77170A61F17962CC4D039692f033b43;
/// @dev Whitelisted NFT: Cigawrettes
address constant CIGAWRETTE = 0xEEd41d06AE195CA8f5CaCACE4cd691EE75F0683f;
/// @dev Whitelisted NFT: Milady
address constant MILADY = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;
/// @dev Whitelisted NFT: Pixelady
address constant PIXELADY = 0x8Fc0D90f2C45a5e7f94904075c952e0943CFCCfd;
/// @dev Whitelisted NFT: Radbro
address constant RADBRO = 0xABCDB5710B88f456fED1e99025379e2969F29610;
/// @dev Whitelisted NFT: Remilio
address constant REMILIO = 0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB;
/// @dev Whitelisted NFT: SchizoPosters
address constant SCHIZOPOSTER = 0xBfE47D6D4090940D1c7a0066B63d23875E3e2Ac5;

/// @dev Maximum free mints per id per whitelisted user
uint256 constant FREE_MINTS = 7;

/// @dev Maximum mints per id per user
uint256 constant MINT_LIMIT = 69;

/// @title A mint contract for distributing Ashurbanipal passes
///
/// @author Zelinar XY
contract Enkidu is Ownable, Receiver {
    Ashurbanipal private _ashurbanipal;

    /// @notice Address of the contract used to mint NFTs granting permission to write or confirm Nabu works' content
    address private _ashurbanipalAddress;

    ERC20 private _cult;

    ERC721 private _aura;
    ERC721 private _cigawrette;
    ERC721 private _milady;
    ERC721 private _pixelady;
    ERC721 private _radbro;
    ERC721 private _remilio;
    ERC721 private _schizoposter;

    ERC721 private _humbaba;

    /// @notice Address of the contract used to grant free mints to users who don't own any of the whitelisted assets
    address private _humbabaAddress;

    // maps id to price
    mapping(uint256 => uint256) public prices;
    // id
    mapping(uint256 => bool) public active;

    // how many free mints has a user used for an id
    mapping(uint256 => mapping(address => uint256)) public freeMints;

    constructor(address initialAshurbanipalAddress, address initialHumbabaAddress) {
        _initializeOwner(msg.sender);

        _ashurbanipalAddress = initialAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(initialAshurbanipalAddress);

        _humbabaAddress = initialHumbabaAddress;
        _humbaba = ERC721(initialHumbabaAddress);

        _aura = ERC721(AURA);
        _cigawrette = ERC721(CIGAWRETTE);
        _cult = ERC20(CULT);
        _milady = ERC721(MILADY);
        _pixelady = ERC721(PIXELADY);
        _radbro = ERC721(RADBRO);
        _remilio = ERC721(REMILIO);
        _schizoposter = ERC721(SCHIZOPOSTER);
    }

    /// @notice Get the Ashurbanipal contract address
    function ashurbanipalAddress() public view returns (address) {
        return _ashurbanipalAddress;
    }

    /// @notice Get the Humbaba contract address
    function humbabaAddress() public view returns (address) {
        return _humbabaAddress;
    }

    function updateHumbaba(address newHumbabaAddress) public onlyOwner {
        _humbabaAddress = newHumbabaAddress;
        _humbaba = ERC721(newHumbabaAddress);
    }

    function _mint(uint256 id, uint256 count, address to) private {
        if (count == 0) {
            revert ZeroCount();
        }

        _ashurbanipal.safeTransferFrom(address(this), to, id, count, "");
    }

    function adminMint(uint256 id, uint256 count, address to) public onlyOwner {
        _mint(id, count, to);
    }

    // To save gas, the consuming application should check the user's token balances before calling
    // this function and pass an appropriate value for `whitelistedToken`. For example, if the user
    // has already minted 7 free tokens, we know they're not eligible to mint any more for free, and
    // we can pass `WhitelistedToken.None` to skip the check. If we know they have a Milady, we can
    // pass `WhitelistedToken.Milady` rather than looping through every collection. If we're not sure,
    // we can pass `WhitelistedToken.Any` to run the exhaustive check.
    function mint(uint256 id, uint256 count, address to, WhitelistedToken whitelistedToken) public payable {
        if (!active[id]) {
            revert Inactive();
        }

        uint256 existingBalance = _ashurbanipal.balanceOf(to, id);

        if (count + existingBalance > MINT_LIMIT) {
            revert OverLimit();
        }

        uint256 usedFreeMints = freeMints[id][to];
        uint256 remainingFreeMints;

        if (usedFreeMints >= FREE_MINTS) {
            remainingFreeMints = 0;
        } else {
            remainingFreeMints = FREE_MINTS - usedFreeMints;
        }

        bool isWhitelisted;

        if (whitelistedToken == WhitelistedToken.Cult) {
            isWhitelisted = _cult.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Aura) {
            isWhitelisted = _aura.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Cigawrette) {
            isWhitelisted = _cigawrette.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Milady) {
            isWhitelisted = _milady.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Pixelady) {
            isWhitelisted = _pixelady.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Radbro) {
            isWhitelisted = _radbro.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Remilio) {
            isWhitelisted = _remilio.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Schizoposter) {
            isWhitelisted = _schizoposter.balanceOf(to) > 0;
        } else if (whitelistedToken == WhitelistedToken.Humbaba) {
            isWhitelisted = _humbaba.balanceOf(to) > 0;
        }

        if (whitelistedToken == WhitelistedToken.Any || (!isWhitelisted && whitelistedToken != WhitelistedToken.None)) {
            isWhitelisted = _cult.balanceOf(to) > 0 || _aura.balanceOf(to) > 0 || _cigawrette.balanceOf(to) > 0
                || _milady.balanceOf(to) > 0 || _pixelady.balanceOf(to) > 0 || _radbro.balanceOf(to) > 0
                || _remilio.balanceOf(to) > 0 || _schizoposter.balanceOf(to) > 0 || _humbaba.balanceOf(to) > 0;
        }

        uint256 countForPrice = count;

        if (isWhitelisted) {
            if (countForPrice < remainingFreeMints) {
                countForPrice = 0;
            } else {
                countForPrice -= remainingFreeMints;
            }
        }

        uint256 pricePerUnit = prices[id];
        uint256 price = pricePerUnit * countForPrice;

        if (msg.value < price) {
            revert InsufficientFunds();
        }

        _mint(id, count, to);

        if (countForPrice < count) {
            freeMints[id][to] = freeMints[id][to] + count - countForPrice;
        }
    }

    function updateActive(uint256 id, bool isActive) public onlyOwner {
        active[id] = isActive;
    }

    function updatePrice(uint256 id, uint256 price) public onlyOwner {
        prices[id] = price;
    }

    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        _ashurbanipalAddress = newAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    /// @notice Withdraw mint proceeds
    /// @notice Restricted to the contract owner
    ///
    /// @param amount The amount to withdraw; if zero, falls back to the entire balance
    /// @param _to The recipient of the withdrawn funds; falls back to msg.sender
    function withdraw(uint256 amount, address _to) public onlyOwner {
        uint256 amountToWithdraw = amount;

        if (amountToWithdraw == 0) {
            amountToWithdraw = address(this).balance;
        }

        address to = _to;

        if (_to == address(0)) {
            to = msg.sender;
        }

        payable(to).transfer(amountToWithdraw);
    }
}
