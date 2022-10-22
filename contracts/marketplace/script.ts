import { AptosAccount, AptosClient, HexString, TokenClient } from "aptos";
import { DEV_PRIVATE_KEY, NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common"

const SELLER_PRIVATE_KEY = PRIVATE_KEY_ALICE;
const BUYER_PRIVATE_KEY = PRIVATE_KEY_BOB;

const client = new AptosClient(NODE_URL);
const tokenClient = new TokenClient(client);
// dev: owner of the market and collection
const dev = new AptosAccount(DEV_PRIVATE_KEY ? (new HexString(DEV_PRIVATE_KEY)).toUint8Array() : undefined);
const seller = new AptosAccount(SELLER_PRIVATE_KEY ? (new HexString(SELLER_PRIVATE_KEY)).toUint8Array() : undefined);
const buyer = new AptosAccount(BUYER_PRIVATE_KEY ? (new HexString(BUYER_PRIVATE_KEY)).toUint8Array() : undefined);

const devAddr = dev.address().hex();
const marketAddr = `${devAddr}::marketplace01`; // market contract deployed at this address
const randomNumber = Math.ceil(Math.random() * 200); // for test

const collectionName = "Aptos Shogun";
const tokenName = `Aptos Shogun #${randomNumber}`;
const tokenAmount = 1; // NFT
const tokenPropertyVersion = 1; // 0 for ERC 1155, 1 for NFT
let txhHash;

const runDemo = async () => {
    // a demo flow
    // await createCollection(); // run only one time

    await createToken(); // for demo

    // await initializeMarket(); // run only one time

    await listToken();

    await delistToken();

    await listToken();

    await updatePrice();

    await buyToken();
}

(async () => {
    try {
        await runDemo();
    } catch (error) {
        console.error(error);
    }
})();

type EntryFunctionPayload = {
    function: string;
    type_arguments: Array<string>;
    arguments: Array<any>;
};

const transactionWrapper = async (sender: AptosAccount, payload: EntryFunctionPayload) => {
    const rawTxn = await client.generateTransaction(sender.address(), payload);
    const bcsTxn = await client.signTransaction(sender, rawTxn);
    const pendingTxn = await client.submitTransaction(bcsTxn);
    await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}

const createCollection = async () => {
    console.log("=== Creating Collection ===");
    txhHash = await tokenClient.createCollection(
        dev,
        collectionName,
        "This is",
        "https://collection.moe",
    );
    await client.waitForTransaction(txhHash, { checkSuccess: true });
}

const createToken = async () => {
    console.log("=== Creating Token ===");
    console.log(`Token Name: ${tokenName}`);
    txhHash = await tokenClient.createToken(
        dev, // dev: AptosAccount
        collectionName,
        tokenName,
        "The descrition of this token",
        tokenAmount,
        `https://aptos-api-testnet.bluemove.net/uploads/aptos-shogun/${randomNumber}.jpg`, // uri
    );

    await client.waitForTransaction(txhHash, { checkSuccess: true });
    txhHash = await tokenClient.offerToken(
        dev,
        seller.address().hex(),
        devAddr,
        collectionName,
        tokenName,
        tokenAmount,
    );
    await client.waitForTransaction(txhHash, { checkSuccess: true });
    txhHash = await tokenClient.claimToken(
        seller,
        devAddr,
        devAddr,
        collectionName,
        tokenName,
    );
    await client.waitForTransaction(txhHash, { checkSuccess: true });
}

const initializeMarket = async () => {
    console.log("=== Creating marketplace ===");
    await transactionWrapper(dev, // call from dev account
        {
            function: `${marketAddr}::initialize_market`,
            type_arguments: [],
            arguments: [
                devAddr, // admin_address: address,
                devAddr, // fee_recipient: address,
                10, // fee_percentage: u64,
                false // handle_royalty: bool
            ]
        })
    // must call this function to add AptosCoin to whitelist
    await transactionWrapper(dev, {
        function: `${marketAddr}::add_coin_type_to_whitelist`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: []
    })
}

const listToken = async () => {
    console.log("=== List Token marketplace ===");
    await transactionWrapper(seller, // call from user
        {
            function: `${marketAddr}::create_sale`,
            type_arguments: [ '0x1::aptos_coin::AptosCoin' ], // coin type to sell
            arguments: [
                devAddr, // creators_address: address,
                collectionName, // collection: String,
                tokenName, // name: String,
                tokenPropertyVersion, // property_version: u64,
                tokenAmount, // token_amount: u64, 1 for nft
                Math.ceil(Math.random() * 10), // price of token: u64,
                0 // locked_until_secs: u64 (0 for nolock)
            ]
        })
}

const delistToken = async () => {
    console.log("=== Delist Token marketplace ===");
    await transactionWrapper(seller, {
        function: `${marketAddr}::cancel_sale`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [
            devAddr, // creators_address: address,
            collectionName,  // collection: String,
            tokenName,  // name: String,
            tokenPropertyVersion // property_version: u64,
        ]
    })
}

const updatePrice = async () => {
    console.log("=== Update Price marketplace ===");
    await transactionWrapper(seller, {
        function: `${marketAddr}::edit_price`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [
            devAddr,  // creators_address: address,
            collectionName,  // collection: String,
            tokenName,  // name: String,
            tokenPropertyVersion,  // property_version: u64,
            2 // price_per_token: u64 (new price)
        ]
    })
}

const buyToken = async () => {
    console.log("=== Buy Token marketplace ===");
    await transactionWrapper(buyer, {
        function: `${marketAddr}::make_order`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [
            seller.address().hex(),  // token_seller: address,
            devAddr,  // creators_address: address,
            collectionName,  // collection: String,
            tokenName,  // name: String,
            tokenPropertyVersion,  //  property_version: u64,
            tokenAmount // token_amount: u64,
        ]
    })
}
