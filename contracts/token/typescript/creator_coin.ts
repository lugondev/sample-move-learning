// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0
import { FAUCET_URL, NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common";
import { AptosAccount, AptosClient, HexString } from "aptos";

const MODULE_NAME = "token05"

class CoinClient extends AptosClient {
    constructor() {
        super(NODE_URL);
    }

    async createCoin(module: AptosAccount, owner: AptosAccount, name: string, symbol: string, supply: number | bigint): Promise<string> {
        const rawTxn = await this.generateTransaction(owner.address(), {
            function: `${module.address()}::${MODULE_NAME}::create`,
            type_arguments: [ `${owner.address()}::${MODULE_NAME}::LUS` ],
            arguments: [ name, symbol, 8, supply ],
        });

        const bcsTxn = await this.signTransaction(owner, rawTxn);
        const pendingTxn = await this.submitTransaction(bcsTxn);

        return pendingTxn.hash;
    }
}

/** run our demo! */
async function main() {
    const client = new CoinClient();
    console.log({ NODE_URL, FAUCET_URL })

    const alice = new AptosAccount(new HexString(PRIVATE_KEY_ALICE).toUint8Array());
    const bob = new AptosAccount(new HexString(PRIVATE_KEY_BOB).toUint8Array());

    console.log(`Alice: ${alice.address()}`);
    console.log(`Bob: ${bob.address()}`);

    let txnHash
    txnHash = await client.createCoin(alice, alice, "TokenName01", "TN01", 10 * 10 ** 8);
    await client.waitForTransaction(txnHash, { checkSuccess: true });
    console.log("done alice:", txnHash)

    // txnHash = await client.createCoin(alice, bob, "TokenName01", "TN01", 10 * 10 ** 8);
    // await client.waitForTransaction(txnHash, { checkSuccess: true });
    // console.log("done bob:", txnHash)

}

if (require.main === module) {
    main().catch((resp) => console.log(resp));
}
