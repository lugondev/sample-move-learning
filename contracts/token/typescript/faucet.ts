import { AptosAccount, FaucetClient, HexString } from "aptos";
import { FAUCET_URL, NODE_URL, PRIVATE_KEY_ALICE, PRIVATE_KEY_BOB } from "./common";

(async () => {
    // Create API and faucet clients.
    // :!:>section_1
    const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL); // <:!:section_1

    const alice = new AptosAccount(new HexString(PRIVATE_KEY_ALICE).toUint8Array());
    const bob = new AptosAccount(new HexString(PRIVATE_KEY_BOB).toUint8Array());

    console.log("\n=== Addresses ===");
    console.log(`Alice: ${alice.address()}`);
    console.log(`Bob: ${bob.address()}`);
    // Fund accounts.
    // :!:>section_3
    for (let i = 0; i < 100; i++) {
        await Promise.all([
            faucetClient.fundAccount(alice.address(), 1_000_000_000),
            faucetClient.fundAccount(bob.address(), 1_000_000_000),
        ])
        await faucetClient.fundAccount(alice.address(), 1_000_000_000);
        await faucetClient.fundAccount(bob.address(), 1_000_000_000);
    }
})();
