// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@solady/src/tokens/ERC20.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {Ownable} from "@solady/src/auth/Ownable.sol";
import {Receiver} from "@solady/src/accounts/Receiver.sol";
import {SSTORE2} from "@solady/src/utils/SSTORE2.sol";

import {Ashurbanipal} from "./Ashurbanipal.sol";

/// @dev Can't mint inactive ids
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

/// @title A mint contract for distributing Ashurbanipal NFTs
///
/// @author Zelinar XY
contract Enkidu is Ownable, Receiver {
    Ashurbanipal private _ashurbanipal;

    /// @notice Address of the contract used to mint NFTs granting permission to write or confirm Nabu works' content
    address private _ashurbanipalAddress;

    // Contract instances: whitelisted token and NFTs (including Humbaba, if provided)
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

    /// @notice Map Ashurbanipal ids (corresponding to a Nabu works) to their prices
    mapping(uint256 id => uint256 price) public prices;

    /// @notice Map Ashurbanipal ids (corresponding to a Nabu works) to whether they are active (i.e., can be minted)
    mapping(uint256 id => bool isActive) public active;

    /// @notice How many free mints have been used up per id
    mapping(uint256 id => mapping(address user => uint256 mintsCount)) public usedFreeMints;

    /// @notice Initialize the contract with Ashurbanipal and Humbaba addresses and an owner who can update them
    ///
    /// @param initialAshurbanipalAddress The Ashurbanipal contract address
    /// @param initialHumbabaAddress The Humbaba contract address (optional)
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
    ///
    /// @return ashurbanipalAddress The contract address
    function getAshurbanipalAddress() public view returns (address ashurbanipalAddress) {
        ashurbanipalAddress = _ashurbanipalAddress;
    }

    /// @notice Get the Humbaba contract address
    ///
    /// @return humbabaAddress The contract address
    function getHumbabaAddress() public view returns (address humbabaAddress) {
        humbabaAddress = _humbabaAddress;
    }

    /// @notice Update the Humbaba address and contract instance
    ///
    /// @dev Only the contract owner can call this function
    function updateHumbaba(address newHumbabaAddress) public onlyOwner {
        _humbabaAddress = newHumbabaAddress;
        _humbaba = ERC721(newHumbabaAddress);
    }

    /// @notice Transfer a quantity of Ashurbanipal NFTS to the caller or specified recipient
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    function _mint(uint256 id, uint256 count, address to) private {
        if (count == 0) {
            revert ZeroCount();
        }

        _ashurbanipal.safeTransferFrom({from: address(this), to: to, id: id, amount: count, data: ""});
    }

    /// @notice Transfer Ashurbanipal NFTs to a recipient for free
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    function adminMint(uint256 id, uint256 count, address to) public onlyOwner {
        _mint({id: id, count: count, to: to});
    }

    /// @notice Public "mint" function to transfer a quantity of Ashurbanipal NFTs to a recipient
    ///
    /// @dev The NFTs already exist and are held by the Ashurbanipal contract; "mint" reflects the end-user experience
    /// @dev The caller should specify what whitelisted token they hold (see comment on the `WhitelistedToken` enum)
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param count The quantity of NFTs to transfer
    /// @param to The recipient
    /// @param whitelistedToken A specific whitelistedToken the recipient holds (or `Any` or `None`)
    function mint(uint256 id, uint256 count, address to, WhitelistedToken whitelistedToken) public payable {
        if (!active[id]) {
            revert Inactive();
        }

        uint256 existingBalance = _ashurbanipal.balanceOf({owner: to, id: id});

        // Users can only mint a certain total count per id, regardless of whitelist status
        if (count + existingBalance > MINT_LIMIT) {
            revert OverLimit();
        }

        // Track the number of free mints expended per user per id. Otherwise holders of whitelisted collections could
        // mint endless free Ashurbanipal passes by calling the function multiple times.
        uint256 remainingFreeMints;

        if (usedFreeMints[id][to] >= FREE_MINTS) {
            remainingFreeMints = 0;
        } else {
            remainingFreeMints = FREE_MINTS - usedFreeMints[id][to];
        }

        // Does the user hold a whitelisted collection?
        bool isWhitelisted;

        // No need to perform any checks if the user has maxed out on free mints
        if (remainingFreeMints > 0) {
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

            /**
             * The contract performs an exhaustive check against all whitelisted collections if explicitly instructed to
             * (through `WhitelistedToken.Any`) or if a whitelisted collection was specified, but the balance check for
             * that collection failed. Obviously gas-sensitive users should avoid this scenario if possible. Consuming
             * applications should check users' portfolios ahead of time so they know whether to specify a whitelisted
             * collection or to just pass `WhitelistedToken.None`.
             */
            if (
                whitelistedToken == WhitelistedToken.Any
                    || (!isWhitelisted && whitelistedToken != WhitelistedToken.None)
            ) {
                isWhitelisted = _cult.balanceOf(to) > 0 || _aura.balanceOf(to) > 0 || _cigawrette.balanceOf(to) > 0
                    || _milady.balanceOf(to) > 0 || _pixelady.balanceOf(to) > 0 || _radbro.balanceOf(to) > 0
                    || _remilio.balanceOf(to) > 0 || _schizoposter.balanceOf(to) > 0 || _humbaba.balanceOf(to) > 0;
            }
        }

        // Calculate the total cost of the transaction
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

        // Transfer the passes
        _mint({id: id, count: count, to: to});

        // Track any free mints used
        if (countForPrice < count) {
            usedFreeMints[id][to] = usedFreeMints[id][to] + count - countForPrice;
        }
    }

    /// @notice Update the `active` status for an id
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param isActive The new value for `active`
    function updateActive(uint256 id, bool isActive) public onlyOwner {
        active[id] = isActive;
    }

    /// @notice Update the price for an id
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param id The id of the Ashurbanipal NFT
    /// @param price The new price
    function updatePrice(uint256 id, uint256 price) public onlyOwner {
        prices[id] = price;
    }

    /// @notice Update the Ashurbanipal address and contract instance
    ///
    /// @dev Only the contract owner can call this function
    ///
    /// @param newAshurbanipalAddress The new contract address
    function updateAshurbanipalAddress(address newAshurbanipalAddress) public onlyOwner {
        _ashurbanipalAddress = newAshurbanipalAddress;
        _ashurbanipal = Ashurbanipal(newAshurbanipalAddress);
    }

    /// @notice Withdraw mint proceeds
    ///
    /// @dev Restricted to the contract owner
    /// @dev This function has no reentrancy guard: do not withdraw to an unvetted address
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
