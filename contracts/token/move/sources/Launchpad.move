
module LugonSample::launchpad03 {
    use std::error;
    use std::signer;

    use aptos_std::event::{Self, EventHandle};
    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin, zero};
    use aptos_framework::timestamp;

    const ELAUNCHPAD_NOT_JOIN: u64 = 3;
    const EBUYED: u64 = 4;

    const ELAUNCHPAD_STORE_ALREADY_PUBLISHED: u64 = 5;
    const ELAUNCHPAD_NOT_PUBLISHED: u64 = 6;
    const ELAUNCHPAD_ALREADY_PUBLISHED: u64 = 7;
    const ELAUNCHPAD_NOT_START: u64 = 8;
    const ELAUNCHPAD_ALREADY_END: u64 = 9;
    const ELAUNCHPAD_NOT_END: u64 = 10;
    const EBUY_AMOUNT_TOO_SMALL: u64 = 11;

    // Resource representing a shared account
    struct StoreAccount has key {
        signer_capability: account::SignerCapability,
    }

    struct StoreAccountEvent has key {
        resource_addr: address,
    }

    struct LaunchpadStore<phantom CoinType> has key {
        create_events: EventHandle<CreateEvent>,
    }

    struct CreateEvent has drop, store {
        addr: address,
    }

    struct Launchpad<phantom CoinType> has key {
        coin: Coin<CoinType>,
        raised_aptos: Coin<AptosCoin>,
        raised_amount: u64,
        soft_cap: u64,
        hard_cap: u64,
        start_timestamp_secs: u64,
        end_timestamp_secs: u64,

        usr_minum_amount: u64,
        usr_hard_cap: u64,
        token_sell_rate: u64,
        fee_type: u8,
    }

    struct Buy<phantom CoinType> has key, drop {
        launchpad_owner: address,
        amount: u64,
    }

    public entry fun init(account: &signer) {
        let account_addr = signer::address_of(account);
        let type_info = type_info::type_of<StoreAccount>();
        assert!(account_addr == type_info::account_address(&type_info), 0);
        let (resource_signer, resource_signer_cap) = account::create_resource_account(account, x"01");

        move_to(
            &resource_signer,
            StoreAccount {
                signer_capability: resource_signer_cap,
            }
        );

        move_to(account, StoreAccountEvent {
            resource_addr: signer::address_of(&resource_signer)
        });
    }

    fun init_store_if_not_exist<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<LaunchpadStore<CoinType>>(account_addr)) {
            move_to(account, LaunchpadStore<CoinType> {
                create_events: account::new_event_handle<CreateEvent>(account),
            });
        }
    }

    public entry fun create<CoinType>(
        account: &signer,
        amount: u64,
        soft_cap: u64,
        hard_cap: u64,
        start_timestamp_secs: u64,
        end_timestamp_secs: u64,
        usr_minum_amount: u64,
        usr_hard_cap: u64,
        token_sell_rate: u64,
        fee_type: u8
    )
    acquires LaunchpadStore, StoreAccount, StoreAccountEvent {
        let account_addr = signer::address_of(account);
        assert!(
            !is_registered<CoinType>(account_addr),
            error::invalid_state(ELAUNCHPAD_ALREADY_PUBLISHED),
        );

        let type_info = type_info::type_of<StoreAccount>();
        let sae = borrow_global<StoreAccountEvent>(type_info::account_address(&type_info));
        let shared_account = borrow_global<StoreAccount>(sae.resource_addr);
        let resource_signer = account::create_signer_with_capability(&shared_account.signer_capability);

        init_store_if_not_exist<CoinType>(&resource_signer);

        let launchpad_store = borrow_global_mut<LaunchpadStore<CoinType>>(sae.resource_addr);

        event::emit_event<CreateEvent>(
            &mut launchpad_store.create_events,
            CreateEvent { addr: account_addr },
        );

        let coin = coin::withdraw<CoinType>(account, amount);

        move_to(account, Launchpad<CoinType> {
            coin,
            raised_aptos: zero<AptosCoin>(),
            raised_amount: 0,
            soft_cap,
            hard_cap,
            start_timestamp_secs,
            end_timestamp_secs,
            usr_minum_amount,
            usr_hard_cap,
            token_sell_rate,
            fee_type
        });
    }

    public entry fun buy<CoinType>(account: &signer, owner: address, amount: u64) acquires Launchpad {
        assert!(
            exists<Launchpad<CoinType>>(owner),
            error::not_found(ELAUNCHPAD_NOT_PUBLISHED),
        );
        let account_addr = signer::address_of(account);
        assert!(
            !exists<Buy<CoinType>>(account_addr),
            error::not_found(EBUYED),
        );
        let launchpad = borrow_global_mut<Launchpad<CoinType>>(owner);

        assert!(
            launchpad.start_timestamp_secs < timestamp::now_seconds(),
            error::invalid_state(ELAUNCHPAD_NOT_START),
        );
        assert!(
            launchpad.end_timestamp_secs > timestamp::now_seconds(),
            error::invalid_state(ELAUNCHPAD_ALREADY_END),
        );

        //usr hard cap check
        assert!(amount >= launchpad.usr_minum_amount, error::invalid_state(EBUY_AMOUNT_TOO_SMALL));
        let actual_amount: u64 = amount;
        if (amount > launchpad.usr_hard_cap) {
            actual_amount = launchpad.usr_hard_cap;
        };

        launchpad.raised_amount = launchpad.raised_amount + actual_amount;

        let deposit_coin = coin::withdraw<AptosCoin>(account, actual_amount);
        coin::merge(&mut launchpad.raised_aptos, deposit_coin);

        move_to(account, Buy<CoinType> {
            launchpad_owner: owner,
            amount: actual_amount,
        });
    }

    public entry fun claim<CoinType>(account: &signer, owner: address) acquires Launchpad, Buy {
        assert!(
            exists<Launchpad<CoinType>>(owner),
            error::not_found(ELAUNCHPAD_NOT_PUBLISHED),
        );
        let account_addr = signer::address_of(account);
        assert!(
            exists<Buy<CoinType>>(account_addr),
            error::not_found(ELAUNCHPAD_NOT_JOIN),
        );

        let launchpad = borrow_global_mut<Launchpad<CoinType>>(owner);
        assert!(
            launchpad.end_timestamp_secs < timestamp::now_seconds(),
            error::invalid_state(ELAUNCHPAD_NOT_END),
        );

        let ticket = move_from<Buy<CoinType>>(account_addr);

        if (launchpad.raised_amount > launchpad.soft_cap && launchpad.raised_amount <= launchpad.hard_cap) {
            //calculate token amount claimed when not excess funds
            let claimed_amount: u64 = ticket.amount * launchpad.token_sell_rate;
            let claiming = coin::extract(&mut launchpad.coin, claimed_amount); //change the value of claiming token
            coin::deposit(account_addr, claiming);
            let Buy { launchpad_owner: _launchpad_owner, amount: _amount } = ticket;
        } else if (launchpad.raised_amount > launchpad.hard_cap) {
            //calculate token amount claimed when  excess funds
            //according to the proportation
            let actual_used = ticket.amount * launchpad.hard_cap / launchpad.raised_amount ;
            let claimed_amount: u64 = actual_used * launchpad.token_sell_rate;
            let refund_amount = ticket.amount - actual_used;
            //claim
            let claiming = coin::extract(&mut launchpad.coin, claimed_amount); //change the value of claiming token
            coin::deposit(account_addr, claiming);
            //refund
            let refund = coin::extract(&mut launchpad.raised_aptos, refund_amount);
            coin::deposit(account_addr, refund);
            let Buy { launchpad_owner: _launchpad_owner, amount: _amount } = ticket;
        } else {
            let claiming = coin::extract(
                &mut launchpad.raised_aptos,
                ticket.amount
            ); //change the value of claiming token
            coin::deposit(account_addr, claiming);
            let Buy { launchpad_owner: _launchpad_owner, amount: _amount } = ticket;
        };
    }

    public entry fun settle<CoinType>(account: &signer) acquires Launchpad {
        let account_addr = signer::address_of(account);
        assert!(
            !exists<Launchpad<CoinType>>(account_addr),
            error::not_found(ELAUNCHPAD_NOT_PUBLISHED),
        );
        let launchpad = borrow_global_mut<Launchpad<CoinType>>(account_addr);
        assert!(
            launchpad.end_timestamp_secs < timestamp::now_seconds(),
            error::invalid_state(ELAUNCHPAD_NOT_END),
        );

        if (launchpad.raised_amount > launchpad.soft_cap && launchpad.raised_amount <= launchpad.hard_cap) {
            let claiming = coin::extract_all(&mut launchpad.raised_aptos); //extract all aptos token
            coin::deposit(account_addr, claiming);
        } else if (launchpad.raised_amount > launchpad.hard_cap) {
            let claiming = coin::extract(
                &mut launchpad.raised_aptos,
                launchpad.hard_cap
            ); //extract hard_cap aptos token
            coin::deposit(account_addr, claiming);
        } else {
            let claiming = coin::extract_all(&mut launchpad.coin); //change the value of claiming token
            coin::deposit(account_addr, claiming);
        }
    }

    public fun is_registered<CoinType>(owner: address): bool {
        exists<Launchpad<CoinType>>(owner)
    }

    public entry fun get_launchpad<CoinType>(addr: address): u64 acquires Launchpad {
        borrow_global<Launchpad<CoinType>>(addr).hard_cap
    }
}
