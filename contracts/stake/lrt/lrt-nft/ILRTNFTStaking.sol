// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.6;

/**
 * @title NFT Stake Interface
 * @dev This interface defines the methods and events for managing staking on the LRTNFTStaking contract.
 */
interface ILRTNFTStaking {
    // Struct to keep track of a user's stake details
    struct UserStake {
        uint8 duration; // The duration for which the user's stakes are locked
        uint64 startDate; // The start date of the stake, usually a timestamp
        uint256 stakedAmount; // The amount of tokens that the user has staked
        uint256 tokenId; // The id of token reward.
    }

    // Struct to handle the reward token attributes
    struct RewardToken {
        uint256 rewardLimit; // The maximum limit of reward tokens that can be distributed
        uint256 tokensDistributed; // The total amount of reward tokens that have already been distributed
        uint256 tokenPrice; // The price of reward tokens distributed for each staking event or period
        // uint256 tokenId; // The id of token reward.
    }

    /**
     * @dev Emitted when a user stakes tokens.
     * @param staker The address of the staker.
     * @param amount The amount of tokens staked.
     * @param duration The Id of the staked token.
     * @param rewardCollection The address of the reward collection.
     * @param tokenId The id of tokens reward.
     * @param index The index of the staking schedule.
     * @param apr The annual percentage rate (APR) for the staking schedule when the user staking schedule started.
     */
    event LRTNFTStaked(
        address indexed staker,
        uint256 amount,
        uint8 duration,
        address rewardCollection,
        uint256 tokenId,
        uint16 index,
        uint16 apr
    );

    /**
     * @dev Emitted when a user unstakes tokens.
     * @param staker The address of the staker.
     * @param index The index of the staking schedule.
     * @param amount The amount of tokens staked.
     */
    event LRTNFTUnStaked(address indexed staker, uint16 index, uint256 amount);

    /**
     * @dev Emitted when the APR is updated.
     * @param duration The duration of the staking schedule in months.
     * @param apr The annual percentage rate (APR) for the staking schedule.
     */
    event UpdatedAPR(uint8 duration, uint16 apr);

    /**
     * @dev Emitted when the stake capacity is updated.
     * @param stakeCapacity The maximum stake capacity.
     */
    event UpdatedStakeCapacity(uint256 stakeCapacity);

    /**
     * @dev Emitted when the threshold is updated.
     * @param threshold The threshold amount.
     */
    event UpdatedThreshold(uint256 threshold);

    /**
     * @dev Emitted when the duration is updated.
     * @param duration The duration in months.
     * @param isActive A boolean indicating whether the duration is valid or not.
     */
    event UpdatedDurations(uint8 duration, bool isActive);

    /**
     * @dev Emitted when the duration limit is updated.
     * @param durationLimit The duration limit in seconds.
     */
    event UpdatedDurationLimit(uint64 durationLimit);

    /**
     * @dev Emitted when the reward token's information, such as reward amount or limit, is updated.
     * @param rewardCollection The new address set for the reward collection
     * @param tokenId The unique identifier for the reward token whose data is being updated
     * @param tokenPrice The new price assigned to the reward token
     * @param rewardLimit The new reward limit set for the reward token
     */
    event UpdatedRewardToken(
        address rewardCollection,
        uint256 tokenId,
        uint256 tokenPrice,
        uint256 rewardLimit
    );

    /**
     * @dev Emitted when the reward collection address is updated
     * @param rewardCollection The new address set for the reward collection
     */
    event UpdatedRewardCollection(address rewardCollection);

    /**
     * @dev Initializes the NFTStake contract.
     * @param _accessRestriction The address of the AccessRestriction contract.
     * @param _lrt The address of the LRT contract.
     */
    function initializeNFTStake(
        address _accessRestriction,
        address _lrt
    ) external;

    /**
     * @dev Stakes a specific token.
     * @param _amount The Id of the token to stake.
     * @param _duration The quantity of tokens staked.
     */
    function stake(uint256 _amount, uint8 _duration) external;

    /**
     * @dev Unstakes a specific token.
     * @param _index The index of the staking schedule.
     */
    function unstake(uint16 _index) external;

    /**
     * @dev Sets the APR (Annual Percentage Rate) for a specific duration.
     * @param _duration The duration for which the APR is being set.
     * @param _apr The APR value to be set.
     */
    function setAPR(uint8 _duration, uint16 _apr) external;

    /**
     * @dev Sets the valid durations for staking.
     * @param _duration The duration in months.
     * @param _isActive A boolean indicating whether the duration is valid or not.
     */
    function setDurations(uint8 _duration, bool _isActive) external;

    /**
     * @dev Sets the price of a reward token.
     * @param _tokenId The ID of the reward token.
     * @param _tokenPrice The new price assigned to the reward token
     * @param _rewardLimit The new reward limit set for the reward token
     */
    function setRewardToken(
        uint256 _tokenId,
        uint256 _tokenPrice,
        uint256 _rewardLimit
    ) external;

    /**
     * @dev Sets the threshold amount required for staking.
     * @param _threshold The threshold amount.
     */
    function setThreshold(uint256 _threshold) external;

    /**
     * @dev Sets the duration limit for staking.
     * @param _durationLimit The duration limit in seconds.
     */
    function setDurationLimit(uint64 _durationLimit) external;

    /**
     * @dev Sets the maximum stake capacity allowed by the contract.
     * @param _stakeCapacity The maximum stake capacity.
     * - Only the admin can call this function.
     */
    function setStakeCapacity(uint256 _stakeCapacity) external;

    /**
     * @dev Sets the address of the reward collection.
     * @param _rewardCollection The address of the reward collection contract.
     */
    function setRewardCollection(address _rewardCollection) external;

    /**
     * @dev Retrieves the annual percentage rate (APR) for a specific staking duration.
     * @param _duration The duration for which to retrieve the APR.
     * @return apr The APR for the specified duration.
     */
    function APRs(uint8 _duration) external view returns (uint16 apr);

    /**
     * @dev Returns the stake capacity of the contract for all users.
     * @return The stake capacity.
     */
    function stakeCapacity() external view returns (uint256);

    /**
     * @dev Returns the threshold value.
     * @return The threshold value.
     */
    function threshold() external view returns (uint256);

    /**
     * @dev Returns the total value locked (TVL) in the contract.
     * @return The TVL.
     */
    function tvl() external view returns (uint256);

    /**
     * @dev Returns the total of the reward tokens.
     * @return The total of the reward tokens.
     */
    function totalRewardTokens() external view returns (uint256);

    /**
     * @dev Returns the duration limit.
     * @return The duration limit.
     */
    function durationLimit() external view returns (uint64);

    /**
     * @dev Returns the address of the reward collection.
     * @return The address of the reward collection.
     */
    function rewardCollection() external view returns (address);

    /**
     * @dev Returns staking data for a user's stake.
     * @param _user The Id of the staked token.
     * @param _index The Id of the staked token.
     * @return duration The quantity of tokens staked.
     * @return startDate The Id of the staked token.
     * @return stakedAmount The quantity of claimed planet.
     * @return tokenId The id of token reward.
     */
    function userStakes(
        address _user,
        uint16 _index
    )
        external
        view
        returns (
            uint8 duration,
            uint64 startDate,
            uint256 stakedAmount,
            uint256 tokenId
        );
    /**
     * @dev Retrieves the number of staking schedules for a user.
     * @param _user The address of the user.
     * @return userStakingCount The number of staking schedules for the user.
     */
    function userStat(
        address _user
    ) external view returns (uint16 userStakingCount);

    /**
     * @dev Retrieves reward token details created by Solidity for the public mapping
     * @param _tokenId The ID of the reward token for which to retrieve details
     * @return rewardLimit The maximum limit of reward tokens that can be distributed for the given token ID
     * @return tokensDistributed The total amount of reward tokens that have been distributed for the given token ID
     * @return tokenPrice The price assigned to the reward token
     */
    function rewardTokens(
        uint256 _tokenId
    )
        external
        view
        returns (
            uint256 rewardLimit,
            uint256 tokensDistributed,
            uint256 tokenPrice
        );

    /**
     * @dev Retrieves reward tokens order
     * @param _id An incremental identifier to keep the order of the reward tokens
     * @return tokenId The ID of the reward token
     */
    function rewardTokenIds(
        uint256 _id
    ) external view returns (uint256 tokenId);

    /**
     * @dev Indicates which durations are valid to stake.
     * @param _duration The quantity of tokens staked.
     * @return hasSet Indicates whether the specified duration is set in the mapping.
     */
    function durations(uint8 _duration) external view returns (bool hasSet);
}
