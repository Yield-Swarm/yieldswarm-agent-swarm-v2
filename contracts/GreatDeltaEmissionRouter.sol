// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title GreatDeltaEmissionRouter
/// @notice Routes dynamic emissions into a hardened 50/30/15/5 treasury split.
contract GreatDeltaEmissionRouter {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    int256 private constant SCALE = 1_000_000;
    uint256 private constant MULTISIG_THRESHOLD = 2;

    bytes32 private constant ACTION_UPDATE_TREASURIES =
        keccak256("ACTION_UPDATE_TREASURIES");
    bytes32 private constant ACTION_UPDATE_EMISSION_CONFIG =
        keccak256("ACTION_UPDATE_EMISSION_CONFIG");
    bytes32 private constant ACTION_ROTATE_SIGNERS =
        keccak256("ACTION_ROTATE_SIGNERS");

    struct EmissionConfig {
        uint256 baseEmissionWei;
        uint16 minPowMultiplierBps;
        uint16 maxPowMultiplierBps;
        uint16 minCelestialMultiplierBps;
        uint16 maxCelestialMultiplierBps;
        uint8 mandelbrotIterations;
    }

    struct EmissionQuote {
        uint256 emissionWei;
        uint16 powMultiplierBps;
        uint16 celestialMultiplierBps;
        uint256 totalMultiplierBps;
        uint8 escapeIterations;
        int256 cReal;
        int256 cImag;
        uint256 dayOfYear;
        uint256 lunarPhase;
        uint256 stellarDrift;
    }

    error NotSigner(address caller);
    error InvalidSignerSet();
    error InvalidTreasurySet();
    error InvalidEmissionConfig();
    error AlreadyApproved(bytes32 operation, address signer);
    error OperationAlreadyExecuted(bytes32 operation);
    error InsufficientEmissionBalance(uint256 available, uint256 required);
    error EthTransferFailed(address recipient, uint256 amount);

    event DepositReceived(address indexed from, uint256 amount);
    event EmissionRouted(
        address indexed caller,
        uint256 indexed powNonce,
        uint256 emissionWei,
        uint16 powMultiplierBps,
        uint16 celestialMultiplierBps,
        uint256 totalMultiplierBps,
        uint256 toCoreTreasury,
        uint256 toGrowthTreasury,
        uint256 toInsuranceTreasury,
        uint256 toOpsTreasury
    );
    event MandelbrotEvaluated(
        uint256 indexed powNonce,
        uint8 escapeIterations,
        uint16 powMultiplierBps,
        int256 cReal,
        int256 cImag
    );
    event CelestialMultiplierEvaluated(
        uint256 indexed powNonce,
        uint16 celestialMultiplierBps,
        uint256 dayOfYear,
        uint256 lunarPhase,
        uint256 stellarDrift
    );
    event MultiSigApproval(
        bytes32 indexed operation,
        address indexed signer,
        uint256 approvals
    );
    event MultiSigExecuted(bytes32 indexed operation, address indexed signer);
    event TreasuriesUpdated(
        address indexed coreTreasury,
        address indexed growthTreasury,
        address indexed insuranceTreasury,
        address opsTreasury
    );
    event EmissionConfigUpdated(
        uint256 baseEmissionWei,
        uint16 minPowMultiplierBps,
        uint16 maxPowMultiplierBps,
        uint16 minCelestialMultiplierBps,
        uint16 maxCelestialMultiplierBps,
        uint8 mandelbrotIterations
    );
    event SignersRotated(
        address indexed signer0,
        address indexed signer1,
        address indexed signer2
    );

    address[3] public signers;
    mapping(address => bool) public isSigner;

    // Treasury order: [core, growth, insurance, operations]
    address[4] public treasuries;
    EmissionConfig public emissionConfig;

    mapping(bytes32 => mapping(address => bool)) public hasApproved;
    mapping(bytes32 => uint256) public approvalCount;
    mapping(bytes32 => bool) public operationExecuted;

    bool private _locked;

    modifier onlySigner() {
        if (!isSigner[msg.sender]) revert NotSigner(msg.sender);
        _;
    }

    modifier nonReentrant() {
        require(!_locked, "REENTRANCY");
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address[3] memory initialSigners,
        address[4] memory initialTreasuries,
        EmissionConfig memory initialEmissionConfig
    ) payable {
        _setSigners(initialSigners);
        _setTreasuries(initialTreasuries);
        _setEmissionConfig(initialEmissionConfig);

        if (msg.value > 0) {
            emit DepositReceived(msg.sender, msg.value);
        }
    }

    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    /// @notice Adds ETH into the emission reserve.
    function deposit() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    /// @notice Routes one emission cycle from the contract reserve.
    /// @dev Uses dynamic Mandelbrot PoW and celestial multipliers.
    function routeEmission(
        uint256 powNonce
    ) external nonReentrant returns (EmissionQuote memory quote) {
        quote = quoteEmission(powNonce);
        if (address(this).balance < quote.emissionWei) {
            revert InsufficientEmissionBalance(address(this).balance, quote.emissionWei);
        }

        (
            uint256 toCore,
            uint256 toGrowth,
            uint256 toInsurance,
            uint256 toOps
        ) = previewSplit(quote.emissionWei);

        _safeTransferETH(treasuries[0], toCore);
        _safeTransferETH(treasuries[1], toGrowth);
        _safeTransferETH(treasuries[2], toInsurance);
        _safeTransferETH(treasuries[3], toOps);

        emit MandelbrotEvaluated(
            powNonce,
            quote.escapeIterations,
            quote.powMultiplierBps,
            quote.cReal,
            quote.cImag
        );
        emit CelestialMultiplierEvaluated(
            powNonce,
            quote.celestialMultiplierBps,
            quote.dayOfYear,
            quote.lunarPhase,
            quote.stellarDrift
        );
        emit EmissionRouted(
            msg.sender,
            powNonce,
            quote.emissionWei,
            quote.powMultiplierBps,
            quote.celestialMultiplierBps,
            quote.totalMultiplierBps,
            toCore,
            toGrowth,
            toInsurance,
            toOps
        );
    }

    /// @notice Preview dynamic emission for a nonce without routing.
    function quoteEmission(
        uint256 powNonce
    ) public view returns (EmissionQuote memory quote) {
        (
            uint16 powMultiplierBps,
            uint8 escapeIterations,
            int256 cReal,
            int256 cImag
        ) = _mandelbrotPowMultiplier(powNonce);
        (
            uint16 celestialMultiplierBps,
            uint256 dayOfYear,
            uint256 lunarPhase,
            uint256 stellarDrift
        ) = _celestialMultiplier(powNonce);

        uint256 totalMultiplierBps = (uint256(powMultiplierBps) *
            uint256(celestialMultiplierBps)) / BPS_DENOMINATOR;
        uint256 emissionWei = (emissionConfig.baseEmissionWei * totalMultiplierBps) /
            BPS_DENOMINATOR;

        quote = EmissionQuote({
            emissionWei: emissionWei,
            powMultiplierBps: powMultiplierBps,
            celestialMultiplierBps: celestialMultiplierBps,
            totalMultiplierBps: totalMultiplierBps,
            escapeIterations: escapeIterations,
            cReal: cReal,
            cImag: cImag,
            dayOfYear: dayOfYear,
            lunarPhase: lunarPhase,
            stellarDrift: stellarDrift
        });
    }

    /// @notice Zero-dust hardened 50/30/15/5 split.
    /// @dev Final bucket gets the residual remainder to guarantee no dust.
    function previewSplit(
        uint256 amount
    )
        public
        pure
        returns (
            uint256 toCore,
            uint256 toGrowth,
            uint256 toInsurance,
            uint256 toOps
        )
    {
        toCore = (amount * 50) / 100;
        toGrowth = (amount * 30) / 100;
        toInsurance = (amount * 15) / 100;
        toOps = amount - toCore - toGrowth - toInsurance;
    }

    /// @notice First/second signature for treasury update. Executes on 2nd approval.
    function approveTreasuryUpdate(
        address[4] calldata newTreasuries
    ) external onlySigner returns (bytes32 operation, bool executedNow) {
        _validateTreasuries(newTreasuries);
        operation = _operationHash(ACTION_UPDATE_TREASURIES, abi.encode(newTreasuries));
        executedNow = _approveAndCheckExecute(operation);

        if (executedNow) {
            _setTreasuries(newTreasuries);
            emit MultiSigExecuted(operation, msg.sender);
        }
    }

    /// @notice First/second signature for emission config update. Executes on 2nd approval.
    function approveEmissionConfigUpdate(
        EmissionConfig calldata newConfig
    ) external onlySigner returns (bytes32 operation, bool executedNow) {
        _validateEmissionConfig(newConfig);
        operation = _operationHash(
            ACTION_UPDATE_EMISSION_CONFIG,
            abi.encode(newConfig)
        );
        executedNow = _approveAndCheckExecute(operation);

        if (executedNow) {
            _setEmissionConfig(newConfig);
            emit MultiSigExecuted(operation, msg.sender);
        }
    }

    /// @notice First/second signature for signer rotation. Executes on 2nd approval.
    function approveSignerRotation(
        address[3] calldata newSigners
    ) external onlySigner returns (bytes32 operation, bool executedNow) {
        _validateSignerSet(newSigners);
        operation = _operationHash(ACTION_ROTATE_SIGNERS, abi.encode(newSigners));
        executedNow = _approveAndCheckExecute(operation);

        if (executedNow) {
            _setSigners(newSigners);
            emit MultiSigExecuted(operation, msg.sender);
        }
    }

    function _approveAndCheckExecute(
        bytes32 operation
    ) internal returns (bool executedNow) {
        if (operationExecuted[operation]) revert OperationAlreadyExecuted(operation);
        if (hasApproved[operation][msg.sender]) {
            revert AlreadyApproved(operation, msg.sender);
        }

        hasApproved[operation][msg.sender] = true;
        uint256 approvals = ++approvalCount[operation];
        emit MultiSigApproval(operation, msg.sender, approvals);

        if (approvals >= MULTISIG_THRESHOLD) {
            operationExecuted[operation] = true;
            executedNow = true;
        }
    }

    function _operationHash(
        bytes32 action,
        bytes memory payload
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), action, payload));
    }

    function _mandelbrotPowMultiplier(
        uint256 powNonce
    )
        internal
        view
        returns (
            uint16 powMultiplierBps,
            uint8 escapeIterations,
            int256 cReal,
            int256 cImag
        )
    {
        uint256 entropy = uint256(
            keccak256(
                abi.encode(
                    powNonce,
                    block.prevrandao,
                    blockhash(block.number - 1),
                    msg.sender,
                    address(this)
                )
            )
        );

        cReal = int256(entropy % 3_000_001) - 2_000_000; // [-2.0, 1.0]
        cImag = int256((entropy / 3_000_001) % 3_000_001) - 1_500_000; // [-1.5, 1.5]

        int256 zReal = 0;
        int256 zImag = 0;
        uint8 iterations = emissionConfig.mandelbrotIterations;

        for (uint8 i = 0; i < iterations; i++) {
            int256 realSq = (zReal * zReal) / SCALE;
            int256 imagSq = (zImag * zImag) / SCALE;
            int256 twoRealImag = (2 * zReal * zImag) / SCALE;

            zReal = realSq - imagSq + cReal;
            zImag = twoRealImag + cImag;

            if (_abs(zReal) > 2 * SCALE || _abs(zImag) > 2 * SCALE) {
                escapeIterations = i + 1;
                break;
            }
        }

        if (escapeIterations == 0) {
            escapeIterations = iterations;
        }

        uint256 stabilityBps = (uint256(escapeIterations) * BPS_DENOMINATOR) /
            uint256(iterations);
        uint256 span = uint256(emissionConfig.maxPowMultiplierBps) -
            uint256(emissionConfig.minPowMultiplierBps);
        powMultiplierBps = uint16(
            uint256(emissionConfig.minPowMultiplierBps) +
                ((span * stabilityBps) / BPS_DENOMINATOR)
        );
    }

    function _celestialMultiplier(
        uint256 powNonce
    )
        internal
        view
        returns (
            uint16 celestialMultiplierBps,
            uint256 dayOfYear,
            uint256 lunarPhase,
            uint256 stellarDrift
        )
    {
        dayOfYear = (block.timestamp / 1 days) % 365;
        lunarPhase = (block.timestamp / 1 days) % 29;
        stellarDrift =
            (uint256(block.prevrandao) ^
                powNonce ^
                uint256(uint160(msg.sender)) ^
                uint256(uint160(address(this)))) %
            BPS_DENOMINATOR;

        uint256 celestialSignal = (dayOfYear * 37 + lunarPhase * 211 + stellarDrift) %
            BPS_DENOMINATOR;
        uint256 span = uint256(emissionConfig.maxCelestialMultiplierBps) -
            uint256(emissionConfig.minCelestialMultiplierBps);

        celestialMultiplierBps = uint16(
            uint256(emissionConfig.minCelestialMultiplierBps) +
                ((span * celestialSignal) / BPS_DENOMINATOR)
        );
    }

    function _setSigners(address[3] memory newSigners) internal {
        _validateSignerSet(newSigners);

        for (uint256 i = 0; i < 3; i++) {
            address oldSigner = signers[i];
            if (oldSigner != address(0)) {
                isSigner[oldSigner] = false;
            }
        }

        for (uint256 i = 0; i < 3; i++) {
            signers[i] = newSigners[i];
            isSigner[newSigners[i]] = true;
        }

        emit SignersRotated(newSigners[0], newSigners[1], newSigners[2]);
    }

    function _setTreasuries(address[4] memory newTreasuries) internal {
        _validateTreasuries(newTreasuries);
        treasuries = newTreasuries;
        emit TreasuriesUpdated(
            newTreasuries[0],
            newTreasuries[1],
            newTreasuries[2],
            newTreasuries[3]
        );
    }

    function _setEmissionConfig(EmissionConfig memory newConfig) internal {
        _validateEmissionConfig(newConfig);
        emissionConfig = newConfig;
        emit EmissionConfigUpdated(
            newConfig.baseEmissionWei,
            newConfig.minPowMultiplierBps,
            newConfig.maxPowMultiplierBps,
            newConfig.minCelestialMultiplierBps,
            newConfig.maxCelestialMultiplierBps,
            newConfig.mandelbrotIterations
        );
    }

    function _validateSignerSet(address[3] memory proposedSigners) internal pure {
        if (
            proposedSigners[0] == address(0) ||
            proposedSigners[1] == address(0) ||
            proposedSigners[2] == address(0)
        ) revert InvalidSignerSet();
        if (
            proposedSigners[0] == proposedSigners[1] ||
            proposedSigners[0] == proposedSigners[2] ||
            proposedSigners[1] == proposedSigners[2]
        ) revert InvalidSignerSet();
    }

    function _validateTreasuries(address[4] memory newTreasuries) internal pure {
        if (
            newTreasuries[0] == address(0) ||
            newTreasuries[1] == address(0) ||
            newTreasuries[2] == address(0) ||
            newTreasuries[3] == address(0)
        ) revert InvalidTreasurySet();
    }

    function _validateEmissionConfig(EmissionConfig memory cfg) internal pure {
        if (cfg.baseEmissionWei == 0) revert InvalidEmissionConfig();
        if (cfg.minPowMultiplierBps == 0 || cfg.minPowMultiplierBps > cfg.maxPowMultiplierBps) {
            revert InvalidEmissionConfig();
        }
        if (
            cfg.minCelestialMultiplierBps == 0 ||
            cfg.minCelestialMultiplierBps > cfg.maxCelestialMultiplierBps
        ) {
            revert InvalidEmissionConfig();
        }
        if (cfg.maxPowMultiplierBps > 30_000 || cfg.maxCelestialMultiplierBps > 30_000) {
            revert InvalidEmissionConfig();
        }
        if (cfg.mandelbrotIterations < 8 || cfg.mandelbrotIterations > 96) {
            revert InvalidEmissionConfig();
        }
    }

    function _safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert EthTransferFailed(recipient, amount);
        }
    }

    function _abs(int256 value) internal pure returns (int256) {
        return value >= 0 ? value : -value;
    }
}
