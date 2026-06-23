// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title KairosYieldEngine — Poseidon Delta Trident yield routing primitive
/// @notice Multi-collateral ingestion with oracle-driven rate distribution and emergency circuit breaker.
contract KairosYieldEngine {
    enum AssetId {
        wSOL,
        wTON,
        wXRP,
        wLTC,
        wTAO,
        USDC,
        USDT,
        USD1,
        HYPE
    }

    struct YieldModule {
        uint256 totalDeposited;
        uint256 accRewardPerShare;
        uint256 baseRateBps;
        bool active;
    }

    struct OracleSnapshot {
        int256 sentinelGpsHash;
        uint256 nexusHashRate;
        uint256 liquidityScore;
        uint256 timestamp;
        bytes signature;
    }

    uint256 private constant BPS = 10_000;
    uint256 private constant MAX_RATE_BPS = 2_500;

    address public governance;
    address public oracleSigner;
    bool public emergencyPaused;
    uint256 private locked;

    mapping(AssetId => YieldModule) public modules;
    mapping(AssetId => mapping(address => uint256)) public balances;
    mapping(AssetId => mapping(address => uint256)) public rewardDebt;

    event Deposit(address indexed user, AssetId indexed asset, uint256 amount);
    event Withdraw(address indexed user, AssetId indexed asset, uint256 amount);
    event RatesUpdated(AssetId indexed asset, uint256 rateBps);
    event OracleApplied(uint256 timestamp, uint256 avgRateBps);
    event EmergencyPaused(address indexed by);
    event EmergencyResumed(address indexed by);
    event KairosFrozen(address indexed by, string reason);

    error ReentrancyGuard();
    error Paused();
    error Unauthorized();
    error InvalidOracle();
    error UnknownAsset();
    error ZeroAmount();

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

    constructor(address _governance, address _oracleSigner) {
        governance = _governance;
        oracleSigner = _oracleSigner;
        _initModule(AssetId.wSOL, 800);
        _initModule(AssetId.wTON, 750);
        _initModule(AssetId.wXRP, 600);
        _initModule(AssetId.wLTC, 550);
        _initModule(AssetId.wTAO, 900);
        _initModule(AssetId.USDC, 400);
        _initModule(AssetId.USDT, 400);
        _initModule(AssetId.USD1, 450);
        _initModule(AssetId.HYPE, 1200);
    }

    function _initModule(AssetId asset, uint256 baseRateBps) private {
        modules[asset] = YieldModule({
            totalDeposited: 0,
            accRewardPerShare: 0,
            baseRateBps: baseRateBps,
            active: true
        });
    }

    function deposit(AssetId asset, uint256 amount) external payable nonReentrant whenNotPaused {
        if (!modules[asset].active) revert UnknownAsset();
        if (amount == 0) revert ZeroAmount();
        YieldModule storage m = modules[asset];
        balances[asset][msg.sender] += amount;
        m.totalDeposited += amount;
        emit Deposit(msg.sender, asset, amount);
    }

    function withdraw(AssetId asset, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = balances[asset][msg.sender];
        if (bal < amount) revert ZeroAmount();
        balances[asset][msg.sender] = bal - amount;
        modules[asset].totalDeposited -= amount;
        emit Withdraw(msg.sender, asset, amount);
    }

    /// @notice Apply signed off-chain telemetry from Sentinel + Nexus workers.
    function applyOracleRates(OracleSnapshot calldata snap, AssetId[] calldata assets, uint256[] calldata rateBps)
        external
        onlyGov
        whenNotPaused
    {
        if (snap.timestamp + 300 < block.timestamp) revert InvalidOracle();
        if (assets.length != rateBps.length) revert InvalidOracle();
        uint256 sum;
        for (uint256 i; i < assets.length;) {
            if (rateBps[i] > MAX_RATE_BPS) revert InvalidOracle();
            modules[assets[i]].baseRateBps = rateBps[i];
            emit RatesUpdated(assets[i], rateBps[i]);
            sum += rateBps[i];
            unchecked {
                ++i;
            }
        }
        emit OracleApplied(snap.timestamp, sum / assets.length);
    }

    /// @notice Freeze variable execution — route to USD1/USDC delta-neutral pairs.
    function freezeKairosRisk(string calldata reason) external onlyGov {
        modules[AssetId.USDC].baseRateBps = 200;
        modules[AssetId.USDT].baseRateBps = 200;
        modules[AssetId.USD1].baseRateBps = 250;
        modules[AssetId.HYPE].active = false;
        emit KairosFrozen(msg.sender, reason);
    }

    function setEmergencyPause(bool paused) external onlyGov {
        emergencyPaused = paused;
        if (paused) emit EmergencyPaused(msg.sender);
        else emit EmergencyResumed(msg.sender);
    }

    function getModuleRate(AssetId asset) external view returns (uint256) {
        return modules[asset].baseRateBps;
    }
}
