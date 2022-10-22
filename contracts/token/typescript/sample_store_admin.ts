// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0
import { NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common";
import { AptosAccount, AptosClient, HexString } from "aptos";


class CoinClient extends AptosClient {
    constructor() {
        super(NODE_URL);
    }

    async store(module: AptosAccount, signer: AptosAccount, amount: number | bigint): Promise<string> {
        const rawTxn = await this.generateTransaction(signer.address(), {
            function: `${module.address()}::learning02::admin_store`,
            type_arguments: [],
            arguments: [ amount ],
        });

        const bcsTxn = await this.signTransaction(signer, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }

    async setAdmin(module: AptosAccount, signer: AptosAccount, newAdmin: AptosAccount): Promise<string> {
        const rawTxn = await this.generateTransaction(signer.address(), {
            function: `${module.address()}::learning02::set_admin_address`,
            type_arguments: [],
            arguments: [ newAdmin.address().hex() ],
        });

        const bcsTxn = await this.signTransaction(signer, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }
}

/** run our demo! */
async function main() {
    const client = new CoinClient();

    // Create two accounts, Alice and Bob, and fund Alice but not Bob
    const alice = new AptosAccount(new HexString(PRIVATE_KEY_ALICE).toUint8Array());
    const bob = new AptosAccount(new HexString(PRIVATE_KEY_BOB).toUint8Array());

    console.log("\n=== Addresses ===");
    console.log(`Alice: ${alice.address()}`);
    console.log(`Bob: ${bob.address()}`);

    let txnHash = await client.store(alice, alice, Date.now());
    await client.setAdmin(alice, alice, bob);
    await client.setAdmin(alice, bob, alice);
    await client.waitForTransaction(txnHash, { checkSuccess: true });
    console.log("done.");
}

if (require.main === module) {
    main().catch(console.log);
}
