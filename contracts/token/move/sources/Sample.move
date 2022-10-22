module LugonSample::learning07 {
    use std::error;
    use std::signer;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;

    /// Not admin
    const ENOT_ADMIN: u64 = 1;

    /// Invalid value
    const ENOT_INVALID_VALUE: u64 = 2;

    struct LugonSample has key {
        store_event: EventHandle<StoreEvent>,
    }

    struct SampleConfig has key {
        admin_address: address,
    }

    struct PrivateStorage has key {
        num: u64,
    }

    struct PublicStorage has key, store, drop, copy {
        num: u64,
        updated_at: u64,
    }

    struct UsersStorage has key {
        // key is the address for public storage.
        stores: vector<PublicStorage>,
    }

    struct StoreEvent has drop, store {
        user: address,
        num: u64,
        timestamp: u64
    }

    fun init_module(sender: &signer) {
        move_to(sender, SampleConfig {
            admin_address: signer::address_of(sender),
        });
        move_to(sender, PrivateStorage {
            num: 0,
        });
        move_to(sender, LugonSample {
            store_event: account::new_event_handle<StoreEvent>(sender),
        });
    }

    public entry fun set_admin_address(
        sender: &signer,
        admin_address: address,
    ) acquires SampleConfig {
        let config = borrow_global_mut<SampleConfig>(@LugonSample);
        assert!(signer::address_of(sender) == config.admin_address, error::permission_denied(ENOT_ADMIN));
        config.admin_address = admin_address;
    }

    public entry fun admin_store(sender: &signer, x: u64) acquires SampleConfig, PrivateStorage, LugonSample {
        let config = borrow_global_mut<SampleConfig>(@LugonSample);
        assert!(signer::address_of(sender) == config.admin_address, error::permission_denied(ENOT_ADMIN));
        let currentStorage = borrow_global_mut<PrivateStorage>(@LugonSample);
        assert!(currentStorage.num != x, error::invalid_state(ENOT_INVALID_VALUE));

        currentStorage.num = x;

        let sample = borrow_global_mut<LugonSample>(@LugonSample);
        event::emit_event<StoreEvent>(
            &mut sample.store_event,
            StoreEvent {
                user: signer::address_of(sender),
                num: x,
                timestamp: timestamp::now_microseconds(),
            },
        );
    }

    fun initialize_user_storage(user: &signer) {
        let addr = signer::address_of(user);
        if (!exists<UsersStorage>(addr)) {
            let storage = UsersStorage {
                stores: vector::empty<PublicStorage>(),
            };
            move_to(user, storage);
        };
        if (!exists<PublicStorage>(addr)) {
            move_to(user, PublicStorage {
                num: 0,
                updated_at: 0,
            });
        }
    }

    public entry fun user_store(user: &signer, x: u64) acquires PublicStorage, UsersStorage, LugonSample {
        initialize_user_storage(user);
        let userAddress = signer::address_of(user);

        let userLatest = borrow_global_mut<PublicStorage>(userAddress);
        userLatest.num = x;
        userLatest.updated_at = timestamp::now_microseconds();

        let userStorage = &mut borrow_global_mut<UsersStorage>(userAddress).stores;
        vector::push_back(userStorage, *userLatest);

        let sample = borrow_global_mut<LugonSample>(@LugonSample);
        event::emit_event<StoreEvent>(
            &mut sample.store_event,
            StoreEvent {
                user: signer::address_of(user),
                num: userLatest.num,
                timestamp: userLatest.updated_at,
            },
        );
    }

    #[test(account = @0xC0FFEE, aptos_framework = @aptos_framework)]
    fun test_user_store(
        account: &signer,
        aptos_framework: &signer
    ) acquires PublicStorage, UsersStorage, LugonSample, SampleConfig, PrivateStorage {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        account::create_account_for_test(signer::address_of(account));

        init_module(account);
        admin_store(account, timestamp::now_seconds());
        user_store(account, timestamp::now_seconds());
    }
}
