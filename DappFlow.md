# Dapp Workflow: Sakamoto

This document outlines the development and interaction flow for the Sakamoto dapp, detailing the backend canisters and their intended use by the frontend.

## Backend Canisters

The backend is composed of several Motoko canisters that handle the core logic of the application.

### 1. `ProfileCanister`

-   **File:** `src/Sakamoto_backend/Profile/ProfileCanister.mo`
-   **Purpose:** Manages user profiles.
-   **Key Functions:**
    -   `createProfile(name, profilePic, bio, email)`: Creates a new user profile linked to the caller's Principal ID.
    -   `getProfile(pid)`: Retrieves a user's profile by their Principal ID.
    -   `getMyProfile()`: A convenience function for users to fetch their own profile.
    -   `updateProfile(update)`: Allows users to update their profile information.
    -   `deleteProfile()`: Allows users to delete their own profile.
    -   `updateStakingStats(pid, totalStaked, rewardsEarned)`: **Internal function** to be called by the `StakingCanister` to keep staking information synchronized with the user's profile.

### 2. `StakingCanister`

-   **File:** `src/Sakamoto_backend/Staking/StakingCanister.mo`
-   **Purpose:** Manages staking pools, user stakes, and reward calculations.
-   **Key Functions:**
    -   `createPool(name, apy, minStake, lockPeriodDays)`: **Admin function** to create new staking pools.
    -   `stake(poolId, amount)`: Allows a user to stake a specified amount of ckBTC into a pool.
    -   `claimRewards(stakeId, poolId)`: Allows a user to claim their accumulated rewards from a stake.
    -   `unstake(stakeId, poolId)`: Allows a user to withdraw their staked amount and any remaining rewards after the lock period.
    -   `getUserStakes(user)`: Retrieves all staking positions for a given user.
    -   `getAllPools()`: Returns a list of all available staking pools.
    -   `getPool(poolId)`: Retrieves the details of a specific staking pool.
    -   `getStake(stakeId)`: Retrieves the details of a specific stake.
    -   `getPendingRewards(stakeId, poolId)`: Calculates and returns the pending rewards for a stake without claiming them.
    -   `getStakingStats()`: Provides overall statistics for the staking platform.

### 3. `VaultCanister` (Assumed)

-   **File:** `src/Sakamoto_backend/ckBTCVault/VaultCanister.mo`
-   **Purpose:** Manages user balances of ckBTC. The `StakingCanister` interacts with this canister to handle deposits and withdrawals for staking.
-   **Key Functions (as used by `StakingCanister`):**
    -   `deposit(amount)`: Deposits ckBTC into the user's vault account.
    -   `withdraw(amount)`: Withdraws ckBTC from the user's vault account.
    -   `getBalance(principal)`: Checks the ckBTC balance of a user.
    -   `internalTransfer(from, to, amount)`: Transfers ckBTC between users within the vault.

## Frontend Integration Flow

The frontend will interact with the backend canisters to provide a seamless user experience.

### 1. User Onboarding

1.  **Authentication:** The user authenticates with their Internet Identity.
2.  **Profile Check:** The frontend calls `getProfile` with the user's Principal ID.
3.  **Profile Creation:**
    -   If the profile does not exist, the frontend should prompt the user to create one by calling `createProfile`.
    -   If the profile exists, the frontend displays the user's profile information.

### 2. Staking Flow

1.  **Display Pools:** The frontend calls `getAllPools` from the `StakingCanister` to display a list of available staking pools.
2.  **User Balance:** The frontend calls `getBalance` from the `VaultCanister` to show the user's available ckBTC balance.
3.  **Staking:**
    -   The user selects a pool and enters an amount to stake.
    -   The frontend calls the `stake` function in the `StakingCanister`.
    -   The `StakingCanister` will internally verify the user's balance in the `VaultCanister` before creating the stake.
4.  **Display User Stakes:** The frontend calls `getUserStakes` to display a list of the user's active and inactive stakes. For each stake, it can call `getPendingRewards` to show unclaimed rewards.

### 3. Rewards and Unstaking

1.  **Claiming Rewards:**
    -   The user clicks a "Claim" button on one of their stakes.
    -   The frontend calls `claimRewards`.
    -   The `StakingCanister` calculates the rewards and calls `deposit` on the `VaultCanister` to transfer the rewards to the user's account.
2.  **Unstaking:**
    -   The user clicks an "Unstake" button on a stake that has passed its lock period.
    -   The frontend calls `unstake`.
    -   The `StakingCanister` calculates the final rewards, returns the principal and rewards to the user's vault account by calling `deposit`, and marks the stake as inactive.

### 4. Profile Management

-   The frontend should provide a section where users can view and update their profile information by calling `updateProfile`.
-   The user's profile page should also display their staking statistics by calling `getUserStakes` and aggregating the data. The `totalStaked` and `rewardsEarned` fields in the `Profile` type can be updated by the `StakingCanister` to provide a quick summary.

This flow ensures a clear separation of concerns between the canisters and provides a straightforward path for the frontend to implement the dapp's features.
