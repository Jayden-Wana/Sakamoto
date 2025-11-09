// ============================================
// VAULT CANISTER - Manages ckBTC funds securely
// Save as: VaultCanister.mo
// ============================================

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Hash "mo:base/Hash";

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

    // Transaction history
    type VaultTransaction = {
        txType : Text; // "deposit" or "withdrawal"
        user : Principal;
        amount : Nat;
        timestamp : Int;
        txId : Nat;
    };

    private stable var transactionCounter : Nat = 0;
    private stable var transactionEntries : [(Nat, VaultTransaction)] = [];
    
    private var transactions = HashMap.HashMap<Nat, VaultTransaction>(
        10,
        Nat.equal,
        Hash.hash
    );

    // Upgrade hooks
    system func preupgrade() {
        vaultBalanceEntries := Iter.toArray(vaultBalances.entries());
        transactionEntries := Iter.toArray(transactions.entries());
    };

    system func postupgrade() {
        vaultBalances := HashMap.fromIter<Principal, Nat>(
            vaultBalanceEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        transactions := HashMap.fromIter<Nat, VaultTransaction>(
            transactionEntries.vals(),
            10,
            Nat.equal,
            Hash.hash
        );
        vaultBalanceEntries := [];
        transactionEntries := [];
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

        // Record transaction
        let tx : VaultTransaction = {
            txType = "deposit";
            user = caller;
            amount = amount;
            timestamp = Time.now();
            txId = transactionCounter;
        };
        transactions.put(transactionCounter, tx);
        transactionCounter += 1;

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

        // Record transaction
        let tx : VaultTransaction = {
            txType = "withdrawal";
            user = caller;
            amount = amount;
            timestamp = Time.now();
            txId = transactionCounter;
        };
        transactions.put(transactionCounter, tx);
        transactionCounter += 1;

        return #ok(currentBalance - amount);
    };

    // Get vault balance
    public query func getBalance(user : Principal) : async Nat {
        return Option.get(vaultBalances.get(user), 0);
    };

    // Get transaction history
    public query func getTransactionHistory(user : Principal) : async [VaultTransaction] {
        let allTxs = Iter.toArray(transactions.vals());
        return Array.filter<VaultTransaction>(
            allTxs,
            func(tx : VaultTransaction) : Bool { tx.user == user }
        );
    };
};
