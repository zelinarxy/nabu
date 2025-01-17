# Nabu 𒀭𒀝

Nabu is an experiment in permissionless, decentralized text preservation using the EVM. It provides a structure for dozens, hundreds or thousands of people to collaborate in committing a document to a blockchain so that it can't be tampered with by inquisitors, fact checkers, trust and safety teams or sensitivity readers.

Anyone can configure a text on Nabu, and anyone can help to populate it. The protocol is designed to prevent malicious actors from vandalizing a text by making it frustrating and expensive, so long as a community committed to preserving the text exists. Here is the process:

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
    metadata: "The Great Book was revealed to the Great Prophet in Year 1 of the New Era and translated to English by Great Sage Jim",
    title: "The Great Book",
    admin: "0xabc...123", // Alice's address 
    totalPassagesCount: 100_000,
    createdAt: 123456, // the block at which Alice initializes the Work
    uri: "https://foo.bar/great-book-metadata.json",
}
```

The Great Book is divided into passages that everyone agrees on (except the hateful schismatics, of whom we don't speak). If the text weren't a standardized classic of this sort, Alice would need to divide it into passages.

At this point Alice could let nature take its course and trust her coreligionists to correctly populate the work. This might just be possible with a devoted community and a standardized text. But let's say she takes a more hands-on approach. Nabu isn't opinionated about this part of the picture, but we could imagine Alice building a SQL database of passages in the Great Book and an API to serve that data to a web UI, where users could click a few buttons to select a passage to commit to the chain and perform the call to the Nabu smart contract.

The only caveat is that these users must hold an ERC-1155 token corresponding to the work (see the `Ashurbanipal` contract), which grants permission to assign content to its passages. When Alice creates the work, in addition to the data related to the text detailed above, she decides on a `supply` of tokens for the work. Those are minted to her wallet automatically, and she's responsible for distributing them to the community.

This introduces a semi-permissioned element to the equation, but Alice isn't able to dictate whose wallets these tokens ultimately end up in. People are free to sell or give them away without her approval.

Let's say Alice has distributed the tokens to her community and deployed a sleek website where they can populate the shell of the Great Book with holy writ. First, Bob picks a passage and writes the content to it. Next Charlie comes and confirms that this is the correct content, either by writing it again identically or calling a simpler confirm function. Finally Dave confirms it a second time, and now the passage is set in stone, so to speak.

There are problems with this arrangement, however. The state, media, law enforcement and educational establishment are rabidly hostile to Alice's community and always have been. Legion bigots obtain tokens letting them smear hateful heresies all over the Great Book. They confirm each other's vandalism, committing it to the chain forever and ruining the project.

Not quite. Alice, as the work's initiator (`admin`), can overwrite a confirmed passage. She can't set her preferred content in stone by herself. In that sense, she's like any other user. But she can reset the process and let the community try to overcome censorship again. Ultimately it becomes a contest of wills and—to the extent the gas piles up—resources.

When every passage has been correctly committed to the chain, Alice can renounce her admin status. The Great Book is preserved forever. Yay.
