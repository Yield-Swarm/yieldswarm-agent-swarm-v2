# Copy to deploy-vmss.secrets.ps1 (gitignored) — do not commit real keys.
#   Copy-Item scripts/azure/deploy-vmss.config.example.ps1 deploy-vmss.secrets.ps1

$ResourceGroupName = "YieldSwarm"
$Location          = "centralus"
$VmssName          = "yieldswarm-vmss-cluster"
$InstanceCount     = 16
$VmSize            = "Standard_D4s_v5"   # GPU: Standard_NC24ads_A100_v4 (quota required)

$GeoCronData       = "GEOCRON_ALPHA_2026_STREAM"
$TelemetryStream   = "https://mainnet.yieldswarm.network/api/telemetry"
$FleetApiKey       = "CHANGEME-from-vault-or-operator"
$VaultAddr         = "https://vault.yieldswarm.io:8200"

# Optional: Terminus naming
# $ResourceGroupName = "Terminus-Mainnet-RG"
# $Location          = "eastus2"
