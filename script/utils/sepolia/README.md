# Sepolia utils

## Create work

```
forge script \
  --chain sepolia \
  script/utils/sepolia/CreateWorkSepolia.s.sol:CreateWorkSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

## Write passage

```
forge script \
  --chain sepolia \
  script/utils/sepolia/WritePassageSepolia.s.sol:WritePassageSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

## Admin write passage

```
forge script \
  --chain sepolia \
  script/utils/sepolia/AdminWritePassageSepolia.s.sol:AdminWritePassageSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

## Admin mint Humbaba

```
forge script \
  --chain sepolia \
  script/utils/sepolia/AdminMintHumbabaSepolia.s.sol:AdminMintHumbabaSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

# Configure Enkidu mint

```
forge script \
  --chain sepolia \
  script/utils/sepolia/ConfigureEnkiduMintSepolia.s.sol:ConfigureEnkiduMintSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

# Send eth

```
forge script \
  --chain sepolia \
  script/utils/sepolia/SendEthSepolia.s.sol:SendEthSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

# Mint Enkidu with Humbaba whitelist

```
forge script \
  --chain sepolia \
  script/utils/sepolia/FreeMintEnkiduSepolia.s.sol:FreeMintEnkiduSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```

# Get passage

```
forge script \
  --chain sepolia \
  script/utils/sepolia/GetPassageSepolia.s.sol:GetPassageSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  -vvvv
```

# Confirm passage

```
forge script \
  --chain sepolia \
  script/utils/sepolia/ConfirmPassageSepolia.s.sol:ConfirmPassageSepolia \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vvvv \
  --interactives 1
```
