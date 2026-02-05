# Deploy to Sepolia

For a general guide to Solidity scripting, see the [Foundry docs](https://getfoundry.sh/guides/scripting-with-solidity).

## Deployed contracts

| Contract | Sepolia address | Explorer link |
|---|---|---|
| Ashurbanipal | 0xFcF9aab2af05549a41dC0fd23584A138fC3e1DF2 | [→](https://sepolia.etherscan.io/address/0xfcf9aab2af05549a41dc0fd23584a138fc3e1df2#code) |
| Enkidu | 0xbdA76Dba819272E469Ae9AcCcc9161Cd835e1f5e | [→](https://sepolia.etherscan.io/address/0xbdA76Dba819272E469Ae9AcCcc9161Cd835e1f5e#code) |
| Humbaba | 0x86dD0B9f3BfF7a8fD573A1287da82fA95d8F6FDF | [→](https://sepolia.etherscan.io/address/0x86dd0b9f3bff7a8fd573a1287da82fa95d8f6fdf#code) |
| Nabu | 0x881E623973fe5be9CeeACA91Aa8AA636ee751243 | [→](https://sepolia.etherscan.io/address/0x881e623973fe5be9ceeaca91aa8aa636ee751243#code) |

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

13. This doesn't do anything but it feels wrong not to. Update [DeployedAddressesSepolia.sol](/script/constants/sepolia/DeployedAddressesSepolia.sol#l6).

```
address constant ENKIDU = <deployed address>;
```
