// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0
import dotenv from "dotenv"

dotenv.config();
//:!:>section_1
export const NODE_URL = process.env.APTOS_NODE_URL || "https://fullnode.devnet.aptoslabs.com";
export const FAUCET_URL = process.env.APTOS_FAUCET_URL || "https://faucet.devnet.aptoslabs.com";
export const PRIVATE_KEY_ALICE = process.env.PRIVATE_KEY_ALICE;
export const PRIVATE_KEY_BOB = process.env.PRIVATE_KEY_BOB;
//<:!:section_1

export const aptosCoinStore = "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>";
