import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Option "mo:base/Option";

actor ProfileCanister {
    
    // Profile type definition
    type Profile = {
        pid: Principal;
        name: Text;
        profilePic: ?Text; // Optional URL or base64 string
        bio: ?Text;
        email: ?Text;
        createdAt: Int;
        updatedAt: Int;
        totalStaked: Nat;
        rewardsEarned: Nat;
    };

    // Profile update input type
    type ProfileUpdate = {
        name: ?Text;
        profilePic: ?Text;
        bio: ?Text;
        email: ?Text;
    };

    // Create a stable variable for upgrades
    private stable var profileEntries : [(Principal, Profile)] = [];
    
    // HashMap to store profiles
    private var profiles = HashMap.HashMap<Principal, Profile>(
        10,
        Principal.equal,
        Principal.hash
    );

    // System functions for canister upgrades
    system func preupgrade() {
        profileEntries := Iter.toArray(profiles.entries());
    };

    system func postupgrade() {
        profiles := HashMap.fromIter<Principal, Profile>(
            profileEntries.vals(),
            10,
            Principal.equal,
            Principal.hash
        );
        profileEntries := [];
    };

    // Helper function to get caller's principal
    private func getCallerId() : Principal {
        return Principal.fromActor(ProfileCanister);
    };

    // Create a new profile
    public shared(msg) func createProfile(
        name: Text,
        profilePic: ?Text,
        bio: ?Text,
        email: ?Text
    ) : async Result.Result<Profile, Text> {
        let caller = msg.caller;
        
        // Check if profile already exists
        switch (profiles.get(caller)) {
            case (?_) {
                return #err("Profile already exists for this principal");
            };
            case null {
                let now = Time.now();
                let newProfile : Profile = {
                    pid = caller;
                    name = name;
                    profilePic = profilePic;
                    bio = bio;
                    email = email;
                    createdAt = now;
                    updatedAt = now;
                    totalStaked = 0;
                    rewardsEarned = 0;
                };
                
                profiles.put(caller, newProfile);
                return #ok(newProfile);
            };
        };
    };

    // Get profile by principal (can query own or others)
    public query func getProfile(pid: Principal) : async ?Profile {
        return profiles.get(pid);
    };

    // Get caller's own profile
    public shared(msg) func getMyProfile() : async ?Profile {
        return profiles.get(msg.caller);
    };

    // Update profile
    public shared(msg) func updateProfile(update: ProfileUpdate) : async Result.Result<Profile, Text> {
        let caller = msg.caller;
        
        switch (profiles.get(caller)) {
            case null {
                return #err("Profile not found. Please create a profile first.");
            };
            case (?existingProfile) {
                let updatedProfile : Profile = {
                    pid = existingProfile.pid;
                    name = Option.get(update.name, existingProfile.name);
                    profilePic = switch(update.profilePic) {
                        case (?pic) { ?pic };
                        case null { existingProfile.profilePic };
                    };
                    bio = switch(update.bio) {
                        case (?b) { ?b };
                        case null { existingProfile.bio };
                    };
                    email = switch(update.email) {
                        case (?e) { ?e };
                        case null { existingProfile.email };
                    };
                    createdAt = existingProfile.createdAt;
                    updatedAt = Time.now();
                    totalStaked = existingProfile.totalStaked;
                    rewardsEarned = existingProfile.rewardsEarned;
                };
                
                profiles.put(caller, updatedProfile);
                return #ok(updatedProfile);
            };
        };
    };

    // Delete profile
    public shared(msg) func deleteProfile() : async Result.Result<Text, Text> {
        let caller = msg.caller;
        
        switch (profiles.get(caller)) {
            case null {
                return #err("Profile not found");
            };
            case (?_) {
                profiles.delete(caller);
                return #ok("Profile deleted successfully");
            };
        };
    };

    // Update staking stats (to be called by staking canister)
    public shared(msg) func updateStakingStats(
        pid: Principal,
        totalStaked: Nat,
        rewardsEarned: Nat
    ) : async Result.Result<Profile, Text> {
        // In production, add authorization check here
        // to ensure only staking canister can call this
        
        switch (profiles.get(pid)) {
            case null {
                return #err("Profile not found");
            };
            case (?existingProfile) {
                let updatedProfile : Profile = {
                    pid = existingProfile.pid;
                    name = existingProfile.name;
                    profilePic = existingProfile.profilePic;
                    bio = existingProfile.bio;
                    email = existingProfile.email;
                    createdAt = existingProfile.createdAt;
                    updatedAt = Time.now();
                    totalStaked = totalStaked;
                    rewardsEarned = rewardsEarned;
                };
                
                profiles.put(pid, updatedProfile);
                return #ok(updatedProfile);
            };
        };
    };

    // Get all profiles (for admin or leaderboard)
    public query func getAllProfiles() : async [Profile] {
        return Iter.toArray(profiles.vals());
    };

    // Get total number of profiles
    public query func getProfileCount() : async Nat {
        return profiles.size();
    };

    // Check if profile exists
    public query func profileExists(pid: Principal) : async Bool {
        return Option.isSome(profiles.get(pid));
    };

    // Get multiple profiles by PIDs
    public query func getProfilesBatch(pids: [Principal]) : async [?Profile] {
        return Array.map<?Profile, Principal>(
            pids,
            func(pid: Principal) : ?Profile {
                profiles.get(pid)
            }
        );
    };
}