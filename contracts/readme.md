# Steps
## At move directory
```shell

# get faucet devnet
aptos account fund-with-faucet --account default
aptos account fund-with-faucet --account bob

# compile move
aptos move compile --named-addresses LugonSample=default

# publish move
aptos move publish --named-addresses LugonSample=default
```

## At typescript directory
```shell
# install dependencies
yarn

#Update PRIVATE_KEY in .env

# run
yarn sample_coin

yarn sample_nft
```
