# Stargate ERC4626 Wrapper

This is an Wrapper for Stargate Protocol which adapts to ERC-4626 (Tokenized Vault) Standard.
It uses the original LP and Underlying tokens from Stargate deployed pools.

### Installing
```
npm update
```

### Testing
#### Local
```
npx hardhat test
```
#### Testnet
1. Create an .env file at the root of the project with content from .env.sample.arbitrum-goerli
2. Export PRIVATE_KEY env variable with connection private key
3. Mint yourself some USDC from https://goerli.arbiscan.io/token/0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291

```
npx hardhat test --network arbitrum
```
If using a testnet different than arbitrum
1. Replace the addresses and poolId in .env file with corresponding ones from https://stargateprotocol.gitbook.io/stargate/developers/contract-addresses/testnet
2. Add the testnet network to hardhat.config.ts
