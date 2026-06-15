// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title GreatDeltaEmissionRouter
/// @notice Routes dynamic block emissions to four multisig wallets with hardened zero-dust split logic.
contract GreatDeltaEmissionRouter {
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant FRACTAL_SCALE = 1e9;
    uint256 private constant FRACTAL_ESCAPE_RADIUS_SQUARED = 4e9;

    IERC20Minimal public immutable rewardToken;
    address public owner;

    // 50/30/15/5 split recipients.
    address public multisig50;
    address public multisig30;
    address public multisig15;
    address public multisig05;

    uint256 public baseRewardPerBlock;
    uint256 public minRewardPerBlock;
    uint256 public maxRewardPerBlock;
    uint256 public projectedStakeBase;
    uint256 public blocksPerYear;
    uint256 public lastDistributedBlock;

    // Mandelbrot multiplier bounds (basis points).
    uint16 public mandelbrotMinBps = 6_000;
    uint16 public mandelbrotMaxBps = 14_000;
    uint8 public mandelbrotMaxIterations = 24;

    // Celestial and precessional multipliers (basis points + cycle lengths in blocks).
    uint16 public celestialMinBps = 9_200;
    uint16 public celestialMaxBps = 10_800;
    uint32 public celestialCycleBlocks = 7_200;

    uint16 public precessionalMinBps = 9_500;
    uint16 public precessionalMaxBps = 10_500;
    uint32 public precessionalCycleBlocks = 21_600;

    uint256 private reentrancyLock = 1;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event WalletsUpdated(address indexed multisig50, address indexed multisig30, address indexed multisig15, address multisig05);
    event EmissionConfigUpdated(
        uint256 baseRewardPerBlock,
        uint256 minRewardPerBlock,
        uint256 maxRewardPerBlock,
        uint256 projectedStakeBase,
        uint256 blocksPerYear
    );
    event MandelbrotConfigUpdated(uint16 minBps, uint16 maxBps, uint8 maxIterations);
    event CelestialConfigUpdated(uint16 minBps, uint16 maxBps, uint32 cycleBlocks);
    event PrecessionalConfigUpdated(uint16 minBps, uint16 maxBps, uint32 cycleBlocks);
    event RewardFunded(address indexed from, uint256 amount);
    event RewardDistributed(
        uint256 indexed blockNumber,
        uint256 reward,
        uint256 mandelbrotBps,
        uint256 celestialBps,
        uint256 precessionalBps,
        uint256 amount50,
        uint256 amount30,
        uint256 amount15,
        uint256 amount05
    );

    error NotOwner();
    error Reentrancy();
    error ZeroAddress();
    error InvalidConfig();
    error NothingToDistribute();
    error InsufficientRewardBalance();
    error ERC20TransferFailed();
    error InvalidBlockRange();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (reentrancyLock != 1) revert Reentrancy();
        reentrancyLock = 2;
        _;
        reentrancyLock = 1;
    }

    constructor(
        address rewardToken_,
        address multisig50_,
        address multisig30_,
        address multisig15_,
        address multisig05_,
        uint256 baseRewardPerBlock_,
        uint256 minRewardPerBlock_,
        uint256 maxRewardPerBlock_,
        uint256 projectedStakeBase_,
        uint256 blocksPerYear_,
        uint256 startBlock_
    ) {
        if (rewardToken_ == address(0)) revert ZeroAddress();
        rewardToken = IERC20Minimal(rewardToken_);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);

        _setWallets(multisig50_, multisig30_, multisig15_, multisig05_);
        _setEmissionConfig(
            baseRewardPerBlock_,
            minRewardPerBlock_,
            maxRewardPerBlock_,
            projectedStakeBase_,
            blocksPerYear_
        );

        lastDistributedBlock = startBlock_ == 0 ? block.number : startBlock_;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setWallets(
        address multisig50_,
        address multisig30_,
        address multisig15_,
        address multisig05_
    ) external onlyOwner {
        _setWallets(multisig50_, multisig30_, multisig15_, multisig05_);
    }

    function setEmissionConfig(
        uint256 baseRewardPerBlock_,
        uint256 minRewardPerBlock_,
        uint256 maxRewardPerBlock_,
        uint256 projectedStakeBase_,
        uint256 blocksPerYear_
    ) external onlyOwner {
        _setEmissionConfig(
            baseRewardPerBlock_,
            minRewardPerBlock_,
            maxRewardPerBlock_,
            projectedStakeBase_,
            blocksPerYear_
        );
    }

    function setMandelbrotConfig(uint16 minBps, uint16 maxBps, uint8 maxIterations) external onlyOwner {
        if (maxIterations == 0 || minBps > maxBps) revert InvalidConfig();
        mandelbrotMinBps = minBps;
        mandelbrotMaxBps = maxBps;
        mandelbrotMaxIterations = maxIterations;
        emit MandelbrotConfigUpdated(minBps, maxBps, maxIterations);
    }

    function setCelestialConfig(uint16 minBps, uint16 maxBps, uint32 cycleBlocks) external onlyOwner {
        if (cycleBlocks == 0 || minBps > maxBps) revert InvalidConfig();
        celestialMinBps = minBps;
        celestialMaxBps = maxBps;
        celestialCycleBlocks = cycleBlocks;
        emit CelestialConfigUpdated(minBps, maxBps, cycleBlocks);
    }

    function setPrecessionalConfig(uint16 minBps, uint16 maxBps, uint32 cycleBlocks) external onlyOwner {
        if (cycleBlocks == 0 || minBps > maxBps) revert InvalidConfig();
        precessionalMinBps = minBps;
        precessionalMaxBps = maxBps;
        precessionalCycleBlocks = cycleBlocks;
        emit PrecessionalConfigUpdated(minBps, maxBps, cycleBlocks);
    }

    /// @notice Deposit reward tokens into the router.
    function fund(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidConfig();
        _safeTransferFrom(address(rewardToken), msg.sender, address(this), amount);
        emit RewardFunded(msg.sender, amount);
    }

    /// @notice Distributes one reward for every undistributed block, up to maxBlocks.
    /// @dev Uses hardened 50/30/15/5 split with dust assigned to the 5% leg to avoid stranded dust.
    function distributePending(uint256 maxBlocks) external nonReentrant returns (uint256 blocksProcessed, uint256 totalReward) {
        if (maxBlocks == 0) revert InvalidBlockRange();
        if (block.number <= lastDistributedBlock) revert NothingToDistribute();

        uint256 toBlock = lastDistributedBlock + maxBlocks;
        if (toBlock > block.number) {
            toBlock = block.number;
        }

        uint256 localLast = lastDistributedBlock;
        for (uint256 b = localLast + 1; b <= toBlock; ) {
            (uint256 reward, uint256 mandelbrotBps, uint256 celestialBps, uint256 precessionalBps) = _projectRewardForBlock(b);
            _routeWithZeroDust(b, reward, mandelbrotBps, celestialBps, precessionalBps);
            totalReward += reward;
            unchecked {
                ++b;
                ++blocksProcessed;
            }
        }

        lastDistributedBlock = toBlock;
    }

    /// @notice Distributes only the current block reward.
    function distributeCurrentBlock() external nonReentrant returns (uint256 reward) {
        if (block.number <= lastDistributedBlock) revert NothingToDistribute();
        (uint256 localReward, uint256 mandelbrotBps, uint256 celestialBps, uint256 precessionalBps) = _projectRewardForBlock(
            block.number
        );
        _routeWithZeroDust(block.number, localReward, mandelbrotBps, celestialBps, precessionalBps);
        reward = localReward;
        lastDistributedBlock = block.number;
    }

    function previewBlockReward(
        uint256 blockNumber
    ) external view returns (uint256 reward, uint256 mandelbrotBps, uint256 celestialBps, uint256 precessionalBps) {
        return _projectRewardForBlock(blockNumber);
    }

    /// @notice View function to inspect current projected APY and source values.
    /// @return apyBps APY in basis points (10_000 = 100%)
    /// @return annualReward Projected annual emissions from current block reward
    /// @return rewardPerBlock Current block's projected reward
    function projectedAPY() external view returns (uint256 apyBps, uint256 annualReward, uint256 rewardPerBlock) {
        (rewardPerBlock, , , ) = _projectRewardForBlock(block.number);
        annualReward = rewardPerBlock * blocksPerYear;
        if (projectedStakeBase == 0) {
            return (0, annualReward, rewardPerBlock);
        }
        apyBps = (annualReward * BPS_DENOMINATOR) / projectedStakeBase;
    }

    function _setWallets(address multisig50_, address multisig30_, address multisig15_, address multisig05_) internal {
        if (
            multisig50_ == address(0) ||
            multisig30_ == address(0) ||
            multisig15_ == address(0) ||
            multisig05_ == address(0)
        ) revert ZeroAddress();

        multisig50 = multisig50_;
        multisig30 = multisig30_;
        multisig15 = multisig15_;
        multisig05 = multisig05_;
        emit WalletsUpdated(multisig50_, multisig30_, multisig15_, multisig05_);
    }

    function _setEmissionConfig(
        uint256 baseRewardPerBlock_,
        uint256 minRewardPerBlock_,
        uint256 maxRewardPerBlock_,
        uint256 projectedStakeBase_,
        uint256 blocksPerYear_
    ) internal {
        if (
            blocksPerYear_ == 0 ||
            maxRewardPerBlock_ < minRewardPerBlock_ ||
            baseRewardPerBlock_ < minRewardPerBlock_ ||
            baseRewardPerBlock_ > maxRewardPerBlock_
        ) revert InvalidConfig();

        baseRewardPerBlock = baseRewardPerBlock_;
        minRewardPerBlock = minRewardPerBlock_;
        maxRewardPerBlock = maxRewardPerBlock_;
        projectedStakeBase = projectedStakeBase_;
        blocksPerYear = blocksPerYear_;

        emit EmissionConfigUpdated(
            baseRewardPerBlock_,
            minRewardPerBlock_,
            maxRewardPerBlock_,
            projectedStakeBase_,
            blocksPerYear_
        );
    }

    function _routeWithZeroDust(
        uint256 blockNumber,
        uint256 reward,
        uint256 mandelbrotBps,
        uint256 celestialBps,
        uint256 precessionalBps
    ) internal {
        if (reward == 0) revert InvalidConfig();
        if (rewardToken.balanceOf(address(this)) < reward) revert InsufficientRewardBalance();

        // Hardened deterministic split:
        //  - 50%, 30%, 15% are floor-divided
        //  - 5% leg receives remainder so no dust can be stranded.
        uint256 amount50 = (reward * 50) / 100;
        uint256 amount30 = (reward * 30) / 100;
        uint256 amount15 = (reward * 15) / 100;
        uint256 amount05 = reward - amount50 - amount30 - amount15;

        _safeTransfer(address(rewardToken), multisig50, amount50);
        _safeTransfer(address(rewardToken), multisig30, amount30);
        _safeTransfer(address(rewardToken), multisig15, amount15);
        _safeTransfer(address(rewardToken), multisig05, amount05);

        emit RewardDistributed(
            blockNumber,
            reward,
            mandelbrotBps,
            celestialBps,
            precessionalBps,
            amount50,
            amount30,
            amount15,
            amount05
        );
    }

    function _projectRewardForBlock(
        uint256 blockNumber
    ) internal view returns (uint256 reward, uint256 mandelbrotBps, uint256 celestialBps, uint256 precessionalBps) {
        mandelbrotBps = _mandelbrotMultiplierBps(blockNumber);
        celestialBps = _cycleMultiplierBps(blockNumber, celestialCycleBlocks, celestialMinBps, celestialMaxBps, 0);
        precessionalBps = _cycleMultiplierBps(
            blockNumber,
            precessionalCycleBlocks,
            precessionalMinBps,
            precessionalMaxBps,
            17
        );

        reward = (baseRewardPerBlock * mandelbrotBps * celestialBps * precessionalBps) /
            BPS_DENOMINATOR /
            BPS_DENOMINATOR /
            BPS_DENOMINATOR;

        if (reward < minRewardPerBlock) {
            reward = minRewardPerBlock;
        } else if (reward > maxRewardPerBlock) {
            reward = maxRewardPerBlock;
        }
    }

    function _mandelbrotMultiplierBps(uint256 blockNumber) internal view returns (uint256 multiplierBps) {
        if (mandelbrotMinBps == mandelbrotMaxBps) {
            return mandelbrotMinBps;
        }

        // Map block number into a deterministic point c = (cr, ci) in [-1, 1] x [-1, 1].
        int256 blockX = int256(blockNumber % 4096) - 2048;
        int256 blockY = int256((blockNumber / 4096) % 4096) - 2048;
        int256 cr = (blockX * int256(FRACTAL_SCALE)) / 2048;
        int256 ci = (blockY * int256(FRACTAL_SCALE)) / 2048;

        int256 zr = 0;
        int256 zi = 0;
        uint8 iterations = 0;
        uint8 maxIterations = mandelbrotMaxIterations;

        while (iterations < maxIterations) {
            int256 zr2 = (zr * zr) / int256(FRACTAL_SCALE);
            int256 zi2 = (zi * zi) / int256(FRACTAL_SCALE);
            if (zr2 + zi2 > int256(FRACTAL_ESCAPE_RADIUS_SQUARED)) {
                break;
            }

            int256 nextZi = ((2 * zr * zi) / int256(FRACTAL_SCALE)) + ci;
            zr = zr2 - zi2 + cr;
            zi = nextZi;
            unchecked {
                ++iterations;
            }
        }

        uint256 spread = mandelbrotMaxBps - mandelbrotMinBps;
        multiplierBps = mandelbrotMinBps + (uint256(iterations) * spread) / maxIterations;
    }

    function _cycleMultiplierBps(
        uint256 blockNumber,
        uint32 cycleBlocks,
        uint16 minBps,
        uint16 maxBps,
        uint256 offset
    ) internal pure returns (uint256) {
        if (minBps == maxBps) {
            return minBps;
        }
        uint256 position = (blockNumber + offset) % cycleBlocks;
        return uint256(minBps) + ((maxBps - minBps) * position) / cycleBlocks;
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, amount));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ERC20TransferFailed();
    }
}
