import { AptosAccount, AptosClient, CoinClient, FaucetClient, HexString, TokenClient } from "aptos";
import { DEV_PRIVATE_KEY, FAUCET_URL, NODE_URL } from "./common"

const WALLETS = [
    "0xbf2705b6262428525219c0144a2b6329fe6c06ff8a7586bd07ee90c844bd35ff",
    "0x4b22142d0aaa4fa23aa9d7872558224ec060cea839089437a285c21318b269e6",
    "0xd5cf7bc8c5ce5375eb5dbf99f9e6aaf924b968b5ee318756c28b88c0688fe887",
    "0xaf281192761dcccbc50f952632818b97010244a94a31f186af680e15de4fda43",
    "0x7e34128dc8ee5dd0bc8798e48a00e111760edda00ae8f4e51058e69235c51bc6"
];

const SELLER_PRIVATE_KEY = WALLETS[Math.floor(Math.random() * WALLETS.length)];
const BUYER_PRIVATE_KEY = WALLETS.filter(k => k != SELLER_PRIVATE_KEY)[Math.floor(Math.random() * (WALLETS.length - 1))];

const client = new AptosClient(NODE_URL);
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);
const tokenClient = new TokenClient(client);
const coinClient = new CoinClient(client);

const dev = new AptosAccount(DEV_PRIVATE_KEY ? (new HexString(DEV_PRIVATE_KEY)).toUint8Array() : undefined);
const devAddr = dev.address().hex();
const marketAddr = `${devAddr}::marketplace01`
const seller = new AptosAccount((new HexString(SELLER_PRIVATE_KEY)).toUint8Array());
const buyer = new AptosAccount(BUYER_PRIVATE_KEY ? (new HexString(BUYER_PRIVATE_KEY)).toUint8Array() : undefined);

const randomNumber = Math.ceil(Math.random() * 200);

const collectionName = "Aptos Shogun";
const tokenName = `Aptos Shogun #${randomNumber}`;
const tokenPropertyVersion = 0;
const tokenId = {
    token_data_id: {
        creator: devAddr,
        collection: collectionName,
        name: tokenName,
    },
    property_version: `${tokenPropertyVersion}`,
};

let txhHash, balance1, balance2;

type EntryFunctionPayload = {
    function: string;
    type_arguments: Array<string>;
    arguments: Array<any>;
};

type TableItemRequest = {
    key_type: string;
    value_type: string;
    key: any;
};

const transactionWrapper = async (sender: AptosAccount, payload: EntryFunctionPayload) => {
    const rawTxn = await client.generateTransaction(sender.address(), payload);
    const bcsTxn = await client.signTransaction(sender, rawTxn);
    const pendingTxn = await client.submitTransaction(bcsTxn);
    await client.waitForTransaction(pendingTxn.hash, { checkSuccess: true });
}

const printWalletAddress = async () => {
    console.log("Dev Address: ", devAddr);
    console.log("Seller Address: ", seller.address().hex());
    console.log("Buyer Address: ", buyer.address().hex());
    await printWalletBalance();
}

const printWalletBalance = async () => {
    console.log(`Dev's aptos coin balance: ${await coinClient.checkBalance(dev)}`);
    console.log(`Seller's aptos coin balance: ${await coinClient.checkBalance(seller)}`);
    console.log(`Buyer's aptos coin balance: ${await coinClient.checkBalance(buyer)}`);
}

const fund = async () => {
    console.log("=== Fund Dev, Seller, Buyer ===");
    await faucetClient.fundAccount(dev.address(), 100_000_000);
    await faucetClient.fundAccount(seller.address(), 100_000_000);
    await faucetClient.fundAccount(buyer.address(), 100_000_000);
}

const createCollection = async () => {
    console.log("=== Creating Collection ===");
    txhHash = await tokenClient.createCollection(
        dev,
        collectionName,
        "Description sample",
        "https://zenno.moe",
    );
    await client.waitForTransaction(txhHash, { checkSuccess: true });
}

const createToken = async () => {
    console.log("=== Creating Token ===");
    console.log(`Token Name: ${tokenName}`);
    txhHash = await tokenClient.createToken(
        dev,
        collectionName,
        tokenName,
        "Influenced by the ancient chronicles of Japan, Aptos Shogun Collection is a collection of 6659 Shogun and their virtual world.",
        1,
        `https://aptos-api-testnet.bluemove.net/uploads/aptos-shogun/${randomNumber}.jpg`,
    );
    await client.waitForTransaction(txhHash, { checkSuccess: true });
    txhHash = await tokenClient.offerToken(
        dev,
        seller.address().hex(),
        devAddr,
        collectionName,
        tokenName,
        1,
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
    await transactionWrapper(dev, {
        function: `${marketAddr}::initialize_market`,
        type_arguments: [],
        arguments: [ devAddr, devAddr, 10, false ]
    })
    await transactionWrapper(dev, {
        function: `${marketAddr}::add_coin_type_to_whitelist`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: []
    })
}

const listToken = async () => {
    console.log("=== List Token marketplace ===");
    await transactionWrapper(seller, {
        function: `${marketAddr}::create_sale`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [ devAddr, collectionName, tokenName, tokenPropertyVersion, 1, Math.ceil(Math.random() * 10), 0 ]
    })
}

const delistToken = async () => {
    console.log("=== Delist Token marketplace ===");
    await transactionWrapper(seller, {
        function: `${marketAddr}::cancel_sale`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [ devAddr, collectionName, tokenName, tokenPropertyVersion ]
    })
}

const updatePrice = async () => {
    console.log("=== Update Price marketplace ===");
    await transactionWrapper(seller, {
        function: `${marketAddr}::edit_price`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [ devAddr, collectionName, tokenName, tokenPropertyVersion, 2 ]
    })
}

const buyToken = async () => {
    console.log("=== Buy Token marketplace ===");
    await transactionWrapper(buyer, {
        function: `${marketAddr}::make_order`,
        type_arguments: [ '0x1::aptos_coin::AptosCoin' ],
        arguments: [ seller.address().hex(), devAddr, collectionName, tokenName, tokenPropertyVersion, 1 ]
    })
}

const createMarketplace = async () => {
    await printWalletAddress();
    // await fund();

    // await createCollection();

    await createToken();

    balance1 = await tokenClient.getTokenForAccount(seller.address(), tokenId);
    console.log(`Seller's token balance: ${balance1["amount"]}`);

    // await initializeMarket();

    await listToken();

    balance1 = await tokenClient.getTokenForAccount(seller.address(), tokenId);
    console.log(`Seller's token balance: ${balance1["amount"]}`);

    await delistToken();

    balance1 = await tokenClient.getTokenForAccount(seller.address(), tokenId);
    console.log(`Seller's token balance: ${balance1["amount"]}`);

    await listToken();

    balance1 = await tokenClient.getTokenForAccount(seller.address(), tokenId);
    console.log(`Seller's token balance: ${balance1["amount"]}`);

    await updatePrice();

    // await buyToken();

    balance1 = await tokenClient.getTokenForAccount(seller.address(), tokenId);
    balance2 = await tokenClient.getTokenForAccount(buyer.address(), tokenId);
    console.log(`Seller's token balance: ${balance1["amount"]}`);
    console.log(`Buyer's token balance: ${balance2["amount"]}`);

    await printWalletBalance();
}

(async () => {
    try {
        await createMarketplace();
    } catch (error) {
        console.error(error);
    }
})();
