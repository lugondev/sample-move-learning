# Steps
## At move directory
aptos init

aptos account fund-with-faucet --account default

aptos move compile --named-addresses ZenCoin=default

aptos move publish --named-addresses ZenCoin=default

## At typescript directory
yarn

yarn install

Update PRIVATE_KEY in .env

yarn run zen_coin

yarn run zen_nft