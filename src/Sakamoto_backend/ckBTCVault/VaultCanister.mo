// ============================================
// VAULT CANISTER - Manages ckBTC funds securely
// Save as: VaultCanister.mo
// ============================================

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Option "mo:base/Option";

actor class VaultCanister() = this {
    
    // Vault balance tracking
    private stable var totalDeposits : Nat = 0;
    private stable var totalWithdrawals : Nat = 0;
    private stable var vaultBalanceEntries : [(Principal, Nat)] = [];
    
    private var vaultBalances = HashMap.HashMap<Principal, Nat>(
        10,
        Principal.equal,
        Principal.hash
    );

    // Upgrade hooks
    system func preupgrade() {
        vaultBalanceEntries := Iter.toArray(vaultBalances.entries());
    };

    system func postupgrade() {
        vaultBalances := HashMap.fromIter<Principal, Nat>(
            vaultBalanceEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        vaultBalanceEntries := [];
    };

    // Deposit ckBTC to vault
    public shared(msg) func deposit(amount : Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;
        
        if (amount == 0) {
            return #err("Amount must be greater than 0");
        };

        // Record the deposit
        let currentBalance = Option.get(vaultBalances.get(caller), 0);
        vaultBalances.put(caller, currentBalance + amount);
        totalDeposits += amount;

        return #ok(currentBalance + amount);
    };

    // Withdraw ckBTC from vault
    public shared(msg) func withdraw(amount : Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;
        
        let currentBalance = Option.get(vaultBalances.get(caller), 0);
        
        if (amount > currentBalance) {
            return #err("Insufficient balance");
        };

        // Update balance
        vaultBalances.put(caller, currentBalance - amount);
        totalWithdrawals += amount;

        return #ok(currentBalance - amount);
    };

    // Get vault balance
    public query func getBalance(user : Principal) : async Nat {
        return Option.get(vaultBalances.get(user), 0);
    };
};