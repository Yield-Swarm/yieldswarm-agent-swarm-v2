// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title GreatDeltaEmissionRouter
/// @notice Splits incoming funds with fixed 50/30/15/5 treasury rails.
contract GreatDeltaEmissionRouter {
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant VAULT_BPS = 5_000; // 50%
    uint256 public constant OPS_BPS = 3_000; // 30%
    uint256 public constant ECOSYSTEM_BPS = 1_500; // 15%
    uint256 public constant SOVEREIGN_RESERVE_BPS = 500; // 5%

    address public owner;
    address public vaultTreasury;
    address public operationsTreasury;
    address public ecosystemTreasury;
    address public sovereignReserveTreasury;

    event TreasuriesUpdated(
        address indexed vaultTreasury,
        address indexed operationsTreasury,
        address indexed ecosystemTreasury,
        address sovereignReserveTreasury
    );
    event EmissionRouted(
        uint256 totalAmount,
        uint256 vaultAmount,
        uint256 operationsAmount,
        uint256 ecosystemAmount,
        uint256 sovereignReserveAmount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor(
        address _vaultTreasury,
        address _operationsTreasury,
        address _ecosystemTreasury,
        address _sovereignReserveTreasury
    ) {
        owner = msg.sender;
        _setTreasuries(_vaultTreasury, _operationsTreasury, _ecosystemTreasury, _sovereignReserveTreasury);
    }

    function setTreasuries(
        address _vaultTreasury,
        address _operationsTreasury,
        address _ecosystemTreasury,
        address _sovereignReserveTreasury
    ) external onlyOwner {
        _setTreasuries(_vaultTreasury, _operationsTreasury, _ecosystemTreasury, _sovereignReserveTreasury);
    }

    function routeEmission() external payable {
        uint256 amount = msg.value;
        require(amount > 0, "ZERO_AMOUNT");

        uint256 vaultAmount = (amount * VAULT_BPS) / BPS_DENOMINATOR;
        uint256 operationsAmount = (amount * OPS_BPS) / BPS_DENOMINATOR;
        uint256 ecosystemAmount = (amount * ECOSYSTEM_BPS) / BPS_DENOMINATOR;
        uint256 sovereignReserveAmount = amount - vaultAmount - operationsAmount - ecosystemAmount;

        _safeTransfer(vaultTreasury, vaultAmount);
        _safeTransfer(operationsTreasury, operationsAmount);
        _safeTransfer(ecosystemTreasury, ecosystemAmount);
        _safeTransfer(sovereignReserveTreasury, sovereignReserveAmount);

        emit EmissionRouted(amount, vaultAmount, operationsAmount, ecosystemAmount, sovereignReserveAmount);
    }

    function _setTreasuries(
        address _vaultTreasury,
        address _operationsTreasury,
        address _ecosystemTreasury,
        address _sovereignReserveTreasury
    ) internal {
        require(_vaultTreasury != address(0), "VAULT_ZERO");
        require(_operationsTreasury != address(0), "OPS_ZERO");
        require(_ecosystemTreasury != address(0), "ECO_ZERO");
        require(_sovereignReserveTreasury != address(0), "SOVEREIGN_ZERO");

        vaultTreasury = _vaultTreasury;
        operationsTreasury = _operationsTreasury;
        ecosystemTreasury = _ecosystemTreasury;
        sovereignReserveTreasury = _sovereignReserveTreasury;

        emit TreasuriesUpdated(_vaultTreasury, _operationsTreasury, _ecosystemTreasury, _sovereignReserveTreasury);
    }

    function _safeTransfer(address recipient, uint256 amount) internal {
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "TRANSFER_FAILED");
    }
}
