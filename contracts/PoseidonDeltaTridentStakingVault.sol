# Poseidon Delta Trident v4 — multi-asset PoS staking vault (YSLR World Chain)
# Deploy with forge on Base mainnet after audit.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title PoseidonDeltaTridentStakingVault — 13-asset PoS incentive vault
/// @notice Supports SOL/ETH/TON/HYPE/FLUX/mSOL/cbETH/cbSOL/USDC/USDT/USD1/ZEC/TAO wrappers on Base.
contract PoseidonDeltaTridentStakingVault {
    struct Vault {
        uint256 rewardRatePerSecond;
        uint256 totalStaked;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        bool isActive;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 rewardsAccumulated;
    }

    address public governance;
    IERC20Minimal public immutable incentiveToken;
    bool public emergencyPaused;
    uint256 private locked;

    mapping(address => Vault) public vaults;
    mapping(address => mapping(address => UserInfo)) public userInfo;

    event Staked(address indexed token, address indexed user, uint256 amount);
    event Withdrawn(address indexed token, address indexed user, uint256 amount);
    event RewardClaimed(address indexed token, address indexed user, uint256 reward);
    event VaultConfigured(address indexed token, uint256 rewardRate, bool isActive);

    error ReentrancyGuard();
    error Paused();
    error Unauthorized();

    modifier nonReentrant() {
        if (locked == 1) revert ReentrancyGuard();
        locked = 1;
        _;
        locked = 0;
    }

    modifier whenNotPaused() {
        if (emergencyPaused) revert Paused();
        _;
    }

    modifier onlyGov() {
        if (msg.sender != governance) revert Unauthorized();
        _;
    }

    constructor(address _governance, address _incentiveToken) {
        governance = _governance;
        incentiveToken = IERC20Minimal(_incentiveToken);
    }

    function configureVault(address token, uint256 rewardRatePerSecond, bool isActive) external onlyGov {
        Vault storage v = vaults[token];
        v.rewardRatePerSecond = rewardRatePerSecond;
        v.isActive = isActive;
        if (v.lastUpdateTime == 0) v.lastUpdateTime = block.timestamp;
        emit VaultConfigured(token, rewardRatePerSecond, isActive);
    }

    function pendingReward(address token, address account) public view returns (uint256) {
        Vault memory v = vaults[token];
        UserInfo memory u = userInfo[token][account];
        uint256 rpt = v.rewardPerTokenStored;
        if (block.timestamp > v.lastUpdateTime && v.totalStaked > 0) {
            uint256 elapsed = block.timestamp - v.lastUpdateTime;
            rpt += (elapsed * v.rewardRatePerSecond * 1e18) / v.totalStaked;
        }
        return ((u.amount * (rpt - u.rewardDebt)) / 1e18) + u.rewardsAccumulated;
    }

    function _updateReward(address token, address account) internal {
        Vault storage v = vaults[token];
        if (v.totalStaked > 0) {
            uint256 elapsed = block.timestamp - v.lastUpdateTime;
            v.rewardPerTokenStored += (elapsed * v.rewardRatePerSecond * 1e18) / v.totalStaked;
        }
        v.lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            UserInfo storage u = userInfo[token][account];
            u.rewardsAccumulated = pendingReward(token, account);
            u.rewardDebt = v.rewardPerTokenStored;
        }
    }

    function stake(address token, uint256 amount) external nonReentrant whenNotPaused {
        require(vaults[token].isActive && amount > 0, "invalid stake");
        _updateReward(token, msg.sender);
        require(IERC20Minimal(token).transferFrom(msg.sender, address(this), amount), "transfer");
        userInfo[token][msg.sender].amount += amount;
        vaults[token].totalStaked += amount;
        emit Staked(token, msg.sender, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused {
        UserInfo storage u = userInfo[token][msg.sender];
        require(u.amount >= amount && amount > 0, "insufficient");
        _updateReward(token, msg.sender);
        u.amount -= amount;
        vaults[token].totalStaked -= amount;
        require(IERC20Minimal(token).transfer(msg.sender, amount), "transfer");
        emit Withdrawn(token, msg.sender, amount);
    }

    function claimReward(address token) external nonReentrant whenNotPaused {
        _updateReward(token, msg.sender);
        UserInfo storage u = userInfo[token][msg.sender];
        uint256 reward = u.rewardsAccumulated;
        if (reward > 0) {
            u.rewardsAccumulated = 0;
            require(incentiveToken.transfer(msg.sender, reward), "incentive transfer");
            emit RewardClaimed(token, msg.sender, reward);
        }
    }

    function setEmergencyPause(bool paused) external onlyGov {
        emergencyPaused = paused;
    }
}
