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
    
    // ckBTC Ledger canister interface
    type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    type TransferArgs = {
        from_subaccount : ?Blob;
        to : Account;
        amount : Nat;
        fee : ?Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    type TransferResult = {
        #Ok : Nat;
        #Err : TransferError;
    };

    type TransferError = {
        #BadFee : { expected_fee : Nat };
        #BadBurn : { min_burn_amount : Nat };
        #InsufficientFunds : { balance : Nat };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : Nat };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    // ckBTC Mainnet Ledger Canister ID
    let ckBTC_LEDGER : Principal = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");
    
    // Vault balance tracking
    private stable var totalDeposits : Nat = 0;
    private stable var totalWithdrawals : Nat = 0;
    private stable var vaultBalanceEntries : [(Principal, Nat)] = [];
    
    private var vaultBalances = HashMap.HashMap<Principal, Nat>(
        10,
        Principal.equal,
        Principal.hash
    );

    // Authorized canisters that can interact with vault
    private stable var authorizedCanisters : [Principal] = [];

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

    // Check if caller is authorized
    private func isAuthorized(caller : Principal) : Bool {
        return Array.find<Principal>(
            authorizedCanisters,
            func(p : Principal) : Bool { p == caller }
        ) != null;
    };

    // Add authorized canister (only callable by vault itself during init)
    public shared(msg) func addAuthorizedCanister(canister : Principal) : async Result.Result<Text, Text> {
        if (msg.caller != Principal.fromActor(this)) {
            return #err("Unauthorized");
        };
        authorizedCanisters := Array.append(authorizedCanisters, [canister]);
        return #ok("Canister authorized");
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

    // Transfer between accounts (for staking operations)
    public shared(msg) func internalTransfer(from : Principal, to : Principal, amount : Nat) : async Result.Result<Text, Text> {
        if (not isAuthorized(msg.caller)) {
            return #err("Unauthorized caller");
        };

        let fromBalance = Option.get(vaultBalances.get(from), 0);
        
        if (amount > fromBalance) {
            return #err("Insufficient balance");
        };

        let toBalance = Option.get(vaultBalances.get(to), 0);
        
        vaultBalances.put(from, fromBalance - amount);
        vaultBalances.put(to, toBalance + amount);

        return #ok("Transfer successful");
    };

    // Get vault balance
    public query func getBalance(user : Principal) : async Nat {
        return Option.get(vaultBalances.get(user), 0);
    };

    // Get total vault stats
    public query func getVaultStats() : async {
        totalDeposits : Nat;
        totalWithdrawals : Nat;
        netBalance : Nat;
    } {
        return {
            totalDeposits = totalDeposits;
            totalWithdrawals = totalWithdrawals;
            netBalance = totalDeposits - totalWithdrawals;
        };
    };

    // Get transaction history
    public query func getTransactionHistory(user : Principal) : async [VaultTransaction] {
        let allTxs = Iter.toArray(transactions.vals());
        return Array.filter<VaultTransaction>(
            allTxs,
            func(tx : VaultTransaction) : Bool { tx.user == user }
        );
    };

    // Get all balances (admin function)
    public query func getAllBalances() : async [(Principal, Nat)] {
        return Iter.toArray(vaultBalances.entries());
    };
};