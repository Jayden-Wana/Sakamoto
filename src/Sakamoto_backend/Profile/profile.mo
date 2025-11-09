import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Error "mo:base/Error";

actor Profile {
    public type Profile = {
        id: Principal;
        name: Text;
        description: Text;
        address: Text;
    };

    private var profiles = Trie.empty<Principal, Profile>();

    public shared (msg) func create_profile(name: Text, description: Text, address: Text) : async Result.Result<Profile, Text> {
        let id = msg.caller;
        if (Trie.get(profiles, id) != null) {
            return #err("Profile already exists");
        };
        let new_profile: Profile = {
            id = id;
            name = name;
            description = description;
            address = address;
        };
        profiles := Trie.put(profiles, id, new_profile);
        return #ok(new_profile);
    }

    public query func read_profile(id: Principal) : async Result.Result<Profile, Text> {
        switch (Trie.get(profiles, id)) {
            case (null) { return #err("Profile not found"); };
            case (?profile) { return #ok(profile); };
        };
    }

    public shared (msg) func update_profile(name: Text, description: Text, address: Text) : async Result.Result<Profile, Text> {
        let id = msg.caller;
        switch (Trie.get(profiles, id)) {
            case (null) { return #err("Profile not found"); };
            case (?profile) {
                let updated_profile: Profile = {
                    id = profile.id;
                    name = name;
                    description = description;
                    address = address;
                };
                profiles := Trie.put(profiles, id, updated_profile);
                return #ok(updated_profile);
            };
        };
    }
}