# Nabu 𒀭𒀝

Nabu is an experiment in permissionless, decentralized text preservation using the EVM. It provides a structure for dozens, hundreds or thousands of people to collaborate in committing a document to a blockchain so that it can't be tampered with by inquisitors, fact checkers, trust and safety teams or sensitivity readers.

## Conceptual introduction

Anyone can configure a text with Nabu, and anyone can help to populate it. The protocol is designed to prevent malicious actors from vandalizing a text by making it frustrating and expensive, so long as a community committed to preserving the text exists. Here is the process:

Alice comes from a persecuted religious community. She wants to protect her people's scripture, the Great Book, from destruction or tampering on Ethereum. She models the Great Book as a `Work`:

```
struct Work {
    string author;
    string metadata;
    string title;
    address admin;
    uint256 totalPassagesCount;
    uint256 createdAt;
    string uri;
}
```

Like so:

```
{
    author: "Great Prophet",
    metadata: "The Great Book was revealed to the Great Prophet in Year 1 of the New Era and translated to English by Great Sage Randy",
    title: "The Great Book",
    admin: "0xabc...123", // Alice's address
    totalPassagesCount: 100_000,
    createdAt: 123456, // the block at which Alice initializes the Work
    uri: "https://foo.bar/great-book-metadata.json",
}
```

The Great Book is divided into passages that everyone in Alice's community agrees on. If the text weren't a standardized classic of this sort, Alice would need to divide it into passages herself.

At this point Alice could let nature take its course and trust her coreligionists to correctly populate the work. This might just be possible with a devoted community and a standardized text. But let's say she takes a more hands-on approach. Nabu isn't opinionated about this part of the picture, but we could imagine Alice building a SQL database of passages in the Great Book and an API to serve that data to a web UI, where users could click a few buttons to select a passage to commit to the chain and perform the call to the Nabu smart contract.

The only caveat is that these users must hold an Ashurbanipal "pass," an ERC-1155 token which grants permission to assign content to a given work's passages (the token `id` in Ashurbanipal corresponds to the work's `id` in Nabu). When Alice creates the work, in addition to the data related to the text detailed above, she decides on a `supply` of Ashurbanipal passes for the work. These are minted to her wallet automatically, and she's responsible for distributing them to the community.

This introduces a semi-permissioned element to the equation, but Alice isn't able to dictate whose wallets these tokens ultimately end up in. People are free to sell or give them away without her approval.

Let's say Alice has distributed the tokens to her community and deployed a sleek website where they can populate the Great Book. First, Bob picks a passage and writes the content to it. Next Charlie comes and confirms that this is the correct content, either by writing it again identically or calling a simpler confirm function. Finally Dave confirms it a second time, and now the passage is set in stone, so to speak.

There are problems with this arrangement, however. The state, media, law enforcement and educational establishment are rabidly hostile to Alice's community and always have been. Legion bigots obtain tokens letting them smear hateful heresies all over the Great Book. They confirm each other's vandalism, committing it to the chain forever and ruining the project.

Not quite. Alice, as the work's initiator (`admin`), can overwrite a passage even once it's been confirmed. She can't set her preferred content in stone by herself. In that sense, she's like any other user. But she can reset the process and let the community try to overcome censorship again. Ultimately it becomes a contest of wills and—considering gas costs—resources.

When every passage has been correctly committed to the chain, Alice can renounce her admin status. The Great Book is preserved forever.

## Contracts

The protocol consists of four contracts. The two mentioned above, Nabu and Ashurbanipal, are mandatory. They could each theoretically be deployed once, and that would suffice, so long as the owner doesn't break the two contracts' interactions by pointing Nabu to a malicious or defective Ashurbanipal instance or vice-versa. (These are the only actions limited to these contracts' owners.)

In an ideal world the Nabu protocol would live in one canonical contract deployment (with one linked Ashurbanipal deployment). This would aid in discovering preserved works, since they'd all be in once place. I have no way of enforcing this outcome, though, so whatever happens, happens.

There are two other contracts that work admins can optionally deploy to aid in distributing Ashurbanipal passes. Enkidu exposes `mint` and `adminMint` functions, price controls and the ability to pause minting. In other words, while not ERC721- or ERC1155-compliant, it simulates a traditional NFT mint contract. Each work admin will need their own contract deployment, because so much of the functionality is `onlyOwner`, but one deployment can handle an arbitrary number of works. Simply pass the Enkidu deployment's address as `mintTo` when calling Nabu's `createWork` function, and the newly minted Ashurbanipal passes will be transferred there.

The final contract, Humbaba, allows an Enkidu deployer to easily whitelist users, letting them mint a limited number of Ashurbanipal passes (via Enkidu) for free. It's a minimal ERC721 contract with an `adminMint` function and not much else. The Enkidu owner will need to point `_humbabaAddress` to their Humbaba deployment. In addition to Humbaba holders, Enkidu is hard-coded to whitelist holders of a number of Remilia assets. As with Enkidu, each work admin will need to deploy their own Humbaba contract, but this can be reused for an arbitrary number of works.

### Nabu 𒀭𒀝

TK (what's useful here?)

### Ashurbanipal 𒀸𒋩𒆕𒀀

TK (what's useful here?)

### Enkidu 𒂗𒆠𒄭

TK (what's useful here?)

### Humbaba 𒄷𒌝𒁀𒁀

TK (what's useful here?)

## Creating a work

Here is a step-by-step guide to creating a work with Nabu:

0. (If you can't use an already-deployed Nabu-Ashurbanipal pair. Recommended if existing deployments haven't been renounced or you don't trust the deployed code for any reason. Not recommended otherwise.) Deploy Nabu. Note the contract address. Deploy Ashurbanipal, passing the Nabu contract address to the constructor as `initialNabuAddress`. Note the Ashurbanipal contract address. Call Nabu's `updateAshurbanipal` function, passing it this address. When you're confident that your setup is correct, call `renounceOwnership` on both Nabu and Ashurbanipal. You have given the world a permissionless tool to more-or-less-eternally preserve human knowledge.

1. (Optional.) Deploy a Humbaba instance. Note the contract address. Only do this if you plan to complete step 2, which is also optional. If you've previously deployed a Humbaba contract for a different work (and you're using the same ethereum address, so that the works have the same `admin`), use that one.

2. (Optional.) Deploy an Enkidu instance. If you're making use of a (hopefully _the_) existing Ashurbanipal contract, pass that contract's address to the constructor function as `initialAshurbanipalAddress`. Use the address of your Humbaba deployment from step 1 for `initialHumbabaAddress`. If you've previously deployed an Enkidu contract for a different work (and you're using the same ethereum address, so that the works have the same `admin`), use that one.

3. Organize the text you want to preserve into passages. This might already be done for you to some extent (e.g., verses in scripture, standardized line or paragraph numbers in classical works), or you might need to do it from scratch. Number these passages, starting with 1: these will be the passage ids. Devise some method by which you and others can quickly and reliably look up the correct content of a passage by its id. This could be a SQL database, a public spreadsheet, an eremite with perfect recall who never sleeps. Probably a SQL database.

4. (Recommended.) Decide on a compression algorithm. I've tested Nabu with [FastLZ](https://github.com/ariya/FastLZ). I don't have any reason to expect that other algorithms would break the protocol, nor do I don't have any evidence they won't. Provide an interface for users to take a human-readable passage, compress it, write it to the chain, read it back from the chain, decompress it, display it. Probably a web UI that talks to a server that talks to a database. These are only suggestions.

5. Decide how many Ashurbanipal passes you want to create to give users permission to populate the work. I have no useful insights into tokenomics, if profit is a motive. I will say that while you can burn passes (the ones you've retained or repurchased, at least), you can't create more.

6. Call Nabu's `createWork` function. Specify the work's `author` ("Miguel de Cervantes"), `title` ("Don Quijote"), `metadata` (an optional string giving some additional information about the work), `totalPassagesCount` (the number of passages from step 3), `uri` (an optional endpoint serving metadata for NFT marketplaces), `supply` (the number of Ashurbanipal passes from step 5), and `mintTo` (the Enkidu address from step 2, if you went that route, or whatever address you want, if not: it falls back to `msg.sender`). You (`msg.sender`) will be the work's admin. This allows you to overwrite passage content indefinitely, but not freeze it. It allows you to update `uri` indefinitely. It allows you to ban (or un-ban) users from writing passage content or transfering Ashurbanipal passes (pertaining to this work) indefinitely. It allows you to update the work's `title`, `author`, `metadata` and `totalPassagesCount` for "30 days" (216_000 blocks). This is a grace period to allow for correcting typos and their arithmetic analogs.

7. Distribute passes. If you're using Enkidu and Humbaba, admin-mint Humbaba NFTs to your favorites, set a price through Enkidu, set the mint to active, and retire.

8. On second thought, do not retire. Explain to your community how to populate the work, using whatever interface you devised for step 4. Monitor the process. If vandals manage to confirm malicious passage content, blacklist them and overwrite those passages (sequence is important here). This may or may not work. I can't guarantee outcomes. Hopefully this is an effective tool for fighting censorship, oblivion and decay.

9. (Recommended once you can verify that the work has been completely and correctly populated and not one minute before.) Renounce your adminship over the work (`updateWorkAdmin(<workId>, <burn address>)`). Thank you for your service.
