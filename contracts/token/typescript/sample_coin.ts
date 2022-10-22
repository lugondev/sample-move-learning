// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0
import { FAUCET_URL, NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common";
import { ApiError, AptosAccount, AptosClient, HexString, MaybeHexString } from "aptos";


class CoinClient extends AptosClient {
    constructor() {
        super(NODE_URL);
    }

    /** Register the receiver account to receive transfers for the new coin. */
    async registerCoin(coinTypeAddress: HexString, coinReceiver: AptosAccount): Promise<string> {
        const rawTxn = await this.generateTransaction(coinReceiver.address(), {
            function: "0x1::managed_coin::register",
            type_arguments: [ `${coinTypeAddress.hex()}::LugonToken01::LUS` ],
            arguments: [],
        });

        const bcsTxn = await this.signTransaction(coinReceiver, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }

    /** Mints the newly created coin to a specified receiver address */
    async mintCoin(minter: AptosAccount, receiverAddress: HexString, amount: number | bigint): Promise<string> {
        const rawTxn = await this.generateTransaction(minter.address(), {
            function: "0x1::managed_coin::mint",
            type_arguments: [ `${minter.address()}::LugonToken01::LUS` ],
            arguments: [ receiverAddress.hex(), amount ],
        });

        const bcsTxn = await this.signTransaction(minter, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }

    /** Return the balance of the newly created coin */
    async getBalance(accountAddress: MaybeHexString, coinTypeAddress: HexString): Promise<string | number> {
        return this.getAccountResource(
            accountAddress,
            `0x1::coin::CoinStore<${coinTypeAddress.hex()}::lugon_coin::A1Coin>`,
        ).then(resource => {
            return parseInt((resource.data as any)["coin"]["value"]);
        }).catch((err: ApiError) => {
            console.log({ err: err.message || err.errorCode })
            return 0
        })
    }

    async isRegistered(accountAddress: MaybeHexString, coinTypeAddress: HexString): Promise<boolean> {
        return this.getAccountResource(
            accountAddress,
            `0x1::coin::CoinStore<${coinTypeAddress.hex()}::lugon_coin::A1Coin>`,
        ).then(resource => {
            console.log({ resource })
            return true;
        }).catch((err: ApiError) => {
            console.log({ err: err.message || err.errorCode })
            return false
        })
    }
}

/** run our demo! */
async function main() {
    const client = new CoinClient();
    console.log({ NODE_URL, FAUCET_URL })

    // Create two accounts, Alice and Bob, and fund Alice but not Bob
    const alice = new AptosAccount(new HexString(PRIVATE_KEY_ALICE).toUint8Array());
    const bob = new AptosAccount(new HexString(PRIVATE_KEY_BOB).toUint8Array());

    console.log("\n=== Addresses ===");
    console.log(`Alice: ${alice.address()}`);
    console.log(`Bob: ${bob.address()}`);

    let isRegisteredCoin = await client.isRegistered(bob.address(), alice.address());

    let txnHash
    if (!isRegisteredCoin) {
        console.log("Bob registers the newly created coin so he can receive it from Alice");
        txnHash = await client.registerCoin(alice.address(), bob);
        await client.waitForTransaction(txnHash, { checkSuccess: true });
    }
    console.log(`Bob's initial Coin balance: ${await client.getBalance(bob.address(), alice.address())}.`);

    console.log("Alice mints Bob some of the new coin.");
    txnHash = await client.mintCoin(alice, bob.address(), 10 * 10 ** 8);
    await client.waitForTransaction(txnHash, { checkSuccess: true });
    console.log(`Bob's updated Coin balance: ${await client.getBalance(bob.address(), alice.address())}.`);
}

if (require.main === module) {
    main().then((resp) => console.log(resp));
}
