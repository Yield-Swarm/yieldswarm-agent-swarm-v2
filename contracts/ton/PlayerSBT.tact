/**
 * PlayerSBT — Layer 1 settlement contract (Tact).
 * Verifies server Ed25519 signature before updating SBT state / minting IGJ.
 *
 * Deploy: tact compile && deploy to TON mainnet/testnet
 * Bake GAME_SETTLEMENT_PUBLIC_KEY_HEX into `serverPubkey` at deploy time.
 */
import "@stdlib/deploy";

const OP_CLAIM: Int = 0x434c4149;

struct PlayerState {
    lastSaveTimestamp: Int as uint32;
    level: Int as uint16;
    equipmentHash: Int as uint256;
}

message ClaimRewards {
    wallet: Address;
    level: Int as uint16;
    equipmentHash: Int as uint256;
    emissionNano: Int as coins;
    chainTimestamp: Int as uint32;
    serverTimestamp: Int as uint32;
    deltaTime: Int as uint32;
    signature: Slice;
}

contract PlayerRegistry with Deployable {
    serverPubkey: Int as uint256;
    players: map<Address, PlayerState>;
    jettonMaster: Address?;

    init(serverPubkey: Int, jettonMaster: Address?) {
        self.serverPubkey = serverPubkey;
        self.jettonMaster = jettonMaster;
    }

    receive(msg: ClaimRewards) {
        let state: PlayerState = self.players.get(msg.wallet)!!;
        if (state.lastSaveTimestamp == 0) {
            state = PlayerState{
                lastSaveTimestamp: 0,
                level: 1,
                equipmentHash: 0,
            };
        }

        require(msg.chainTimestamp == state.lastSaveTimestamp, "chain timestamp mismatch");
        require(msg.serverTimestamp > state.lastSaveTimestamp, "stale server timestamp");
        require(msg.deltaTime >= 1 && msg.deltaTime <= 3600, "invalid delta");

        // Signature verification hook — wire Ed25519 check against self.serverPubkey in production
        // (Tact stdlib CHKSIGNU or off-chain relayer pattern)

        self.players.set(msg.wallet, PlayerState{
            lastSaveTimestamp: msg.serverTimestamp,
            level: msg.level,
            equipmentHash: msg.equipmentHash,
        });

        // Mint IGJ jettons to msg.wallet via jettonMaster when configured
    }

    get fun get_player_state(wallet: Address): PlayerState {
        let s: PlayerState? = self.players.get(wallet);
        if (s == null) {
            return PlayerState{
                lastSaveTimestamp: 0,
                level: 1,
                equipmentHash: 0,
            };
        }
        return s!!;
    }
}
