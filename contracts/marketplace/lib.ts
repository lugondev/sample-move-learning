import { AptosAccount, AptosClient, HexString, Types, TokenTypes } from "aptos";
import { DEV_PRIVATE_KEY, NODE_URL } from "./common"


const client = new AptosClient(NODE_URL);

// dev: owner of the market and collection
const dev = new AptosAccount(DEV_PRIVATE_KEY ? (new HexString(DEV_PRIVATE_KEY)).toUint8Array() : undefined);
const devAddr = dev.address().hex();
const marketAddr = `${devAddr}::marketplace01`; // market contract deployed at this address

export const transactionWrapper = async (sender: AptosAccount, payload: Types.EntryFunctionPayload) => {
    const rawTxn = await client.generateTransaction(sender.address(), payload);
    const bcsTxn = await client.signTransaction(sender, rawTxn);
    const pendingTxn = await client.submitTransaction(bcsTxn);
    await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}

export const listNFT = async (seller: AptosAccount, tokenDataId: TokenTypes.TokenDataId, price: number) => {
    await transactionWrapper(seller, // call from user
        {
            function: `${marketAddr}::create_sale`,
            type_arguments: ['0x1::aptos_coin::AptosCoin'], // coin type to sell
            arguments: [
                tokenDataId.creator, // creators_address: address,
                tokenDataId.collection, // collection: String,
                tokenDataId.name, // name: String,
                1, // property_version: u64,
                1, // token_amount: u64, 1 for nft
                price, // price per token: u64,
                0 // locked_until_secs: u64 (0 for nolock)
            ]
        })
}

export const delistNFT = async (seller: AptosAccount, tokenDataId: TokenTypes.TokenDataId) => {
    await transactionWrapper(seller, {
        function: `${marketAddr}::cancel_sale`,
        type_arguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: [
            tokenDataId.creator, // creators_address: address,
            tokenDataId.collection,  // collection: String,
            tokenDataId.name,  // name: String,
            1 // property_version: u64,
        ]
    })
}

export const updateNFTPrice = async (seller: AptosAccount, tokenDataId: TokenTypes.TokenDataId, newPrice: number) => {
    await transactionWrapper(seller, {
        function: `${marketAddr}::edit_price`,
        type_arguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: [
            tokenDataId.creator,  // creators_address: address,
            tokenDataId.collection,  // collection: String,
            tokenDataId.name,  // name: String,
            1,  // property_version: u64,
            newPrice // price_per_token: u64 (new price)
        ]
    })
}

export const buyNFT = async (buyer: AptosAccount, sellerAddress: string, tokenDataId: TokenTypes.TokenDataId) => {
    await transactionWrapper(buyer, {
        function: `${marketAddr}::make_order`,
        type_arguments: ['0x1::aptos_coin::AptosCoin'],
        arguments: [
            sellerAddress,  // token_seller: address,
            tokenDataId.creator,  // creators_address: address,
            tokenDataId.collection,  // collection: String,
            tokenDataId.name,  // name: String,
            1,  //  property_version: u64,
            1 // token_amount: u64,
        ]
    })
}
