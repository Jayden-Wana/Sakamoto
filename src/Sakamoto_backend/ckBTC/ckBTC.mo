import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Error "mo:base/Error";

actor CkBTCVault {
    private var accounts = Trie.empty<Principal, Nat>();

    public query func get_balance(id: Principal) : async Nat {
        switch (Trie.get(accounts, id)) {
            case (null) { return 0; };
            case (?balance) { return balance; };
        };
    }
}
