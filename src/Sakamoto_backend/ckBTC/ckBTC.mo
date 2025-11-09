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

    public shared (msg) func deposit(amount: Nat) : async Result.Result<Nat, Text> {
        let id = msg.caller;
        let balance = get_balance(id);
        let new_balance = balance + amount;
        accounts := Trie.put(accounts, id, new_balance);
        return #ok(new_balance);
    }
}
