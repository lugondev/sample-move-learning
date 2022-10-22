// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0
import { NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common";
import { AptosAccount, AptosClient, HexString } from "aptos";


class CoinClient extends AptosClient {
    constructor() {
        super(NODE_URL);
    }

    async userStore(module: AptosAccount, signer: AptosAccount, amount: number | bigint): Promise<string> {
        const rawTxn = await this.generateTransaction(signer.address(), {
            function: `${module.address()}::learning07::user_store`,
            type_arguments: [],
            arguments: [ amount ],
        });

        const bcsTxn = await this.signTransaction(signer, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }
}

/** run our demo! */
async function main() {
    const client = new CoinClient();

    const alice = new AptosAccount(new HexString(PRIVATE_KEY_ALICE).toUint8Array());
    const bob = new AptosAccount(new HexString(PRIVATE_KEY_BOB).toUint8Array());
    console.log(`Alice: ${alice.address()}`);
    console.log(`Bob: ${bob.address()}`);

   await Promise.all([alice,bob].map(async (account) => {
       let txnHash = await client.userStore(alice, account, Date.now());
       await client.waitForTransaction(txnHash, { checkSuccess: true });
       console.log("hash:", txnHash);
   }))
    console.log("done.");
}

if (require.main === module) {
    main().catch(console.log);
}
