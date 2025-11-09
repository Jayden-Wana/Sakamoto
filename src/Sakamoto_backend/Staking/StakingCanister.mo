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

actor class StakingCanister(vaultCanisterId : Principal) = this {
    
    type StakePosition = {
        user : Principal;
        amount : Nat;
        startTime : Int;
        lastClaimTime : Int;
        rewardsClaimed : Nat;
        isActive : Bool;
    };

    type StakingPool = {
        poolId : Nat;
        name : Text;
        apy : Nat; // Annual Percentage Yield (in basis points, e.g., 1000 = 10%)
        minStake : Nat;
        lockPeriod : Int; // in nanoseconds
        totalStaked : Nat;
        isActive : Bool;
    };

    // Stable storage
    private stable var poolCounter : Nat = 0;
    private stable var stakeCounter : Nat = 0;
    private stable var poolEntries : [(Nat, StakingPool)] = [];
    private stable var stakeEntries : [(Nat, StakePosition)] = [];
    private stable var userStakesEntries : [(Principal, [Nat])] = [];

    // HashMaps
    private var pools = HashMap.HashMap<Nat, StakingPool>(10, Nat.equal, Hash.hash);
    private var stakes = HashMap.HashMap<Nat, StakePosition>(10, Nat.equal, Hash.hash);
    private var userStakes = HashMap.HashMap<Principal, [Nat]>(
        10,
        Principal.equal,
        Principal.hash
    );

    // Reference to vault canister
    let vault : actor {
        deposit : (Nat) -> async Result.Result<Nat, Text>;
        withdraw : (Nat) -> async Result.Result<Nat, Text>;
        getBalance : (Principal) -> async Nat;
        internalTransfer : (Principal, Principal, Nat) -> async Result.Result<Text, Text>;
    } = actor(Principal.toText(vaultCanisterId));

    // Constants
    private let SECONDS_PER_YEAR : Int = 31_536_000_000_000_000; // nanoseconds in a year
    private let BASIS_POINTS : Nat = 10_000;

    // Upgrade hooks
    system func preupgrade() {
        poolEntries := Iter.toArray(pools.entries());
        stakeEntries := Iter.toArray(stakes.entries());
        userStakesEntries := Iter.toArray(userStakes.entries());
    };

    system func postupgrade() {
        pools := HashMap.fromIter<Nat, StakingPool>(
            poolEntries.vals(),
            10,
            Nat.equal,
            Hash.hash
        );
        stakes := HashMap.fromIter<Nat, StakePosition>(
            stakeEntries.vals(),
            10,
            Nat.equal,
            Hash.hash
        );
        userStakes := HashMap.fromIter<Principal, [Nat]>(
            userStakesEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        poolEntries := [];
        stakeEntries := [];
        userStakesEntries := [];
    };

    // Create a new staking pool
    public shared(msg) func createPool(
        name : Text,
        apy : Nat,
        minStake : Nat,
        lockPeriodDays : Nat
    ) : async Result.Result<StakingPool, Text> {
        // In production, add admin check here
        
        let pool : StakingPool = {
            poolId = poolCounter;
            name = name;
            apy = apy;
            minStake = minStake;
            lockPeriod = Int.abs(lockPeriodDays) * 24 * 60 * 60 * 1_000_000_000;
            totalStaked = 0;
            isActive = true;
        };

        pools.put(poolCounter, pool);
        poolCounter += 1;

        return #ok(pool);
    };

    // Stake ckBTC
    public shared(msg) func stake(poolId : Nat, amount : Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;

        // Validate pool
        let pool = switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?p) {
                if (not p.isActive) { return #err("Pool is not active"); };
                if (amount < p.minStake) { 
                    return #err("Amount below minimum stake"); 
                };
                p
            };
        };

        // Check vault balance
        let vaultBalance = await vault.getBalance(caller);
        if (amount > vaultBalance) {
            return #err("Insufficient balance in vault");
        };

        // Create stake position
        let now = Time.now();
        let stakePos : StakePosition = {
            user = caller;
            amount = amount;
            startTime = now;
            lastClaimTime = now;
            rewardsClaimed = 0;
            isActive = true;
        };

        stakes.put(stakeCounter, stakePos);

        // Update user stakes
        let currentStakes = Option.get(userStakes.get(caller), []);
        userStakes.put(caller, Array.append(currentStakes, [stakeCounter]));

        // Update pool stats
        let updatedPool : StakingPool = {
            poolId = pool.poolId;
            name = pool.name;
            apy = pool.apy;
            minStake = pool.minStake;
            lockPeriod = pool.lockPeriod;
            totalStaked = pool.totalStaked + amount;
            isActive = pool.isActive;
        };
        pools.put(poolId, updatedPool);

        let stakeId = stakeCounter;
        stakeCounter += 1;

        return #ok(stakeId);
    };

    // Calculate pending rewards
    private func calculateRewards(stakePos : StakePosition, pool : StakingPool) : Nat {
        let now = Time.now();
        let timeStaked = now - stakePos.lastClaimTime;
        
        // rewards = (amount * apy * time) / (10000 * year)
        let rewardAmount = (stakePos.amount * pool.apy * Int.abs(timeStaked)) / (BASIS_POINTS * SECONDS_PER_YEAR);
        
        return Int.abs(rewardAmount);
    };

    // Claim rewards
    public shared(msg) func claimRewards(stakeId : Nat, poolId : Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;

        let stakePos = switch (stakes.get(stakeId)) {
            case null { return #err("Stake not found"); };
            case (?s) {
                if (s.user != caller) { return #err("Not your stake"); };
                if (not s.isActive) { return #err("Stake is not active"); };
                s
            };
        };

        let pool = switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?p) { p };
        };

        let rewards = calculateRewards(stakePos, pool);

        if (rewards == 0) {
            return #err("No rewards to claim");
        };

        // Update stake position
        let updatedStake : StakePosition = {
            user = stakePos.user;
            amount = stakePos.amount;
            startTime = stakePos.startTime;
            lastClaimTime = Time.now();
            rewardsClaimed = stakePos.rewardsClaimed + rewards;
            isActive = stakePos.isActive;
        };
        stakes.put(stakeId, updatedStake);

        // Transfer rewards to user's vault balance
        let _ = await vault.deposit(rewards);

        return #ok(rewards);
    };

    // Unstake
    public shared(msg) func unstake(stakeId : Nat, poolId : Nat) : async Result.Result<Nat, Text> {
        let caller = msg.caller;

        let stakePos = switch (stakes.get(stakeId)) {
            case null { return #err("Stake not found"); };
            case (?s) {
                if (s.user != caller) { return #err("Not your stake"); };
                if (not s.isActive) { return #err("Stake already withdrawn"); };
                s
            };
        };

        let pool = switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?p) { p };
        };

        // Check lock period
        let now = Time.now();
        if (now - stakePos.startTime < pool.lockPeriod) {
            return #err("Lock period not ended");
        };

        // Calculate final rewards
        let finalRewards = calculateRewards(stakePos, pool);

        // Update stake as inactive
        let updatedStake : StakePosition = {
            user = stakePos.user;
            amount = stakePos.amount;
            startTime = stakePos.startTime;
            lastClaimTime = now;
            rewardsClaimed = stakePos.rewardsClaimed + finalRewards;
            isActive = false;
        };
        stakes.put(stakeId, updatedStake);

        // Update pool
        let updatedPool : StakingPool = {
            poolId = pool.poolId;
            name = pool.name;
            apy = pool.apy;
            minStake = pool.minStake;
            lockPeriod = pool.lockPeriod;
            totalStaked = pool.totalStaked - stakePos.amount;
            isActive = pool.isActive;
        };
        pools.put(poolId, updatedPool);

        // Return funds to vault
        let totalReturn = stakePos.amount + finalRewards;
        let _ = await vault.deposit(totalReturn);

        return #ok(totalReturn);
    };

    // Get user stakes
    public query func getUserStakes(user : Principal) : async [StakePosition] {
        let stakeIds = Option.get(userStakes.get(user), []);
        return Array.mapFilter<Nat, StakePosition>(
            stakeIds,
            func(id : Nat) : ?StakePosition {
                stakes.get(id)
            }
        );
    };

    // Get all pools
    public query func getAllPools() : async [StakingPool] {
        return Iter.toArray(pools.vals());
    };

    // Get pool by ID
    public query func getPool(poolId : Nat) : async ?StakingPool {
        return pools.get(poolId);
    };

    // Get stake details
    public query func getStake(stakeId : Nat) : async ?StakePosition {
        return stakes.get(stakeId);
    };

    // Get pending rewards
    public query func getPendingRewards(stakeId : Nat, poolId : Nat) : async Result.Result<Nat, Text> {
        let stakePos = switch (stakes.get(stakeId)) {
            case null { return #err("Stake not found"); };
            case (?s) { s };
        };

        let pool = switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?p) { p };
        };

        let rewards = calculateRewards(stakePos, pool);
        return #ok(rewards);
    };

    // Get total staking stats
    public query func getStakingStats() : async {
        totalPools : Nat;
        totalActiveStakes : Nat;
        totalValueLocked : Nat;
    } {
        let allPools = Iter.toArray(pools.vals());
        let totalValueLocked = Array.foldLeft<StakingPool, Nat>(
            allPools,
            0,
            func(acc, pool) : Nat { acc + pool.totalStaked }
        );

        let allStakes = Iter.toArray(stakes.vals());
        let activeStakes = Array.filter<StakePosition>(
            allStakes,
            func(stake) : Bool { stake.isActive }
        );

        return {
            totalPools = pools.size();
            totalActiveStakes = activeStakes.size();
            totalValueLocked = totalValueLocked;
        };
    };

    // Emergency pause pool (admin only)
    public shared(msg) func pausePool(poolId : Nat) : async Result.Result<Text, Text> {
        // Add admin authorization check here
        
        switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?pool) {
                let updatedPool : StakingPool = {
                    poolId = pool.poolId;
                    name = pool.name;
                    apy = pool.apy;
                    minStake = pool.minStake;
                    lockPeriod = pool.lockPeriod;
                    totalStaked = pool.totalStaked;
                    isActive = false;
                };
                pools.put(poolId, updatedPool);
                return #ok("Pool paused successfully");
            };
        };
    };

    // Reactivate pool (admin only)
    public shared(msg) func activatePool(poolId : Nat) : async Result.Result<Text, Text> {
        // Add admin authorization check here
        
        switch (pools.get(poolId)) {
            case null { return #err("Pool not found"); };
            case (?pool) {
                let updatedPool : StakingPool = {
                    poolId = pool.poolId;
                    name = pool.name;
                    apy = pool.apy;
                    minStake = pool.minStake;
                    lockPeriod = pool.lockPeriod;
                    totalStaked = pool.totalStaked;
                    isActive = true;
                };
                pools.put(poolId, updatedPool);
                return #ok("Pool activated successfully");
            };
        };
    };
};
