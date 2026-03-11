# Deploy to Sepolia

For a general guide to Solidity scripting, see the [Foundry docs](https://getfoundry.sh/guides/scripting-with-solidity).

## Deployed contracts

| Contract | Sepolia address | Explorer link |
|---|---|---|
| Ashurbanipal | 0x723dAbBF163c75Da3Ff04649bBB439AE1a16732b | [→](https://sepolia.etherscan.io/address/0x723dAbBF163c75Da3Ff04649bBB439AE1a16732b#code) |
| Enkidu | 0x134016FFbb3c4E0BAc15Fb4f18cA097e6408A635 | [→](https://sepolia.etherscan.io/address/0x134016FFbb3c4E0BAc15Fb4f18cA097e6408A635#code) |
| Humbaba | 0x310766caa36FDa354E401E08f8c334A5047edC7F | [→](https://sepolia.etherscan.io/address/0x310766caa36FDa354E401E08f8c334A5047edC7F#code) |
| Nabu | 0x8952E3068398cAA5E56Af52c1733c17c3d5F4F79 | [→](https://sepolia.etherscan.io/address/0x8952E3068398cAA5E56Af52c1733c17c3d5F4F79#code) |

## Steps

0. Create a burner address/private key pair and fund it with Sepolia ether.

```
cast wallet new
```

1. Populate `.env`. 

```
ETHERSCAN_API_KEY=<your key>
SEPOLIA_RPC_URL=<your url>
```

2. `source .env`

3. Deploy Nabu. You'll be prompted to enter your private key in the console. This isn't secure for addresses with funds on mainnet so be sure to use a burner.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/DeployNabuSepolia.s.sol:DeployNabuSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --interactives 1
```

If verificaction fails:

```
forge verify-contract \
  <contract address> \
  src/Nabu.sol:Nabu \
  --chain sepolia
```

4. Update [DeployedAddressesSepolia.sol](/script/constants/sepolia/DeployedAddressesSepolia.sol#l8).

```
address constant NABU = <deployed address>;
```

5. Deploy Ashurbanipal.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/DeployAshurbanipalSepolia.s.sol:DeployAshurbanipalSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --interactives 1
```

6. Update [DeployedAddressesSepolia.sol](/script/constants/sepolia/DeployedAddressesSepolia.sol#l5).

```
address constant ASHURBANIPAL = <deployed address>;
```

7. Update the Nabu contract with the new Ashurbanipal address.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/UpdateAshurbanipalAddressSepolia.s.sol:UpdateAshurbanipalAddressSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

8. Check that the Nabu contract points to Ashurbanipal (`getAshurbanipalAddress()`) and the Ashurbanipal contract points to Nabu (`getNabuAddress()`). If they're properly linked, renounce ownership of both contracts.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/RenounceOwnershipSepolia.s.sol:RenounceOwnershipSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

9. If desired, update [DeployHumbabaSepolia.s.sol](/script/deploy/sepolia/DeployHumbabaSepolia.s.sol#l8).

```
string constant BASE_URI = <your metadata base uri>;
```

10. Deploy Humbaba.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/DeployHumbabaSepolia.s.sol:DeployHumbabaSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --interactives 1
```

11. Update [DeployedAddressesSepolia.sol](/script/constants/sepolia/DeployedAddressesSepolia.sol#l7).

```
address constant HUMBABA = <deployed address>;
```

12. Deploy Enkidu.

```
forge script \
  --chain sepolia \
  script/deploy/sepolia/DeployEnkiduSepolia.s.sol:DeployEnkiduSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --interactives 1
```

13. Update [DeployedAddressesSepolia.sol](/script/constants/sepolia/DeployedAddressesSepolia.sol#l6).

```
address payable constant ENKIDU = payable(<deployed address>);
```
