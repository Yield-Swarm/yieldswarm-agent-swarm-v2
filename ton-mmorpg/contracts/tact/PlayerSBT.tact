import "@stdlib/deploy";
import "@stdlib/ownable";

message UpdatePlayer {
    owner: Address;
    newLastUpdate: Int as uint32;
    earnedNano: Int as coins;
}

struct PlayerRecord {
    lastUpdate: Int as uint32;
    accumulatedNano: Int as coins;
    mintedIgj: Int as uint128;
}

/// Soulbound player state — server updates via authorized signer.
contract PlayerSBT with Deployable, Ownable {
    players: map<Address, PlayerRecord>;
    authorizedServer: Address?;

    init(owner: Address) {
        self.ownable::init(owner);
    }

    receive(msg: UpdatePlayer) {
        self.requireAuthorizedServer();
        let rec: PlayerRecord = self.players.get(msg.owner)!!;
        rec.lastUpdate = msg.newLastUpdate;
        rec.accumulatedNano = rec.accumulatedNano + msg.earnedNano;
        self.players.set(msg.owner, rec);
    }

    get fun last_update(owner: Address): Int {
        let rec: PlayerRecord? = self.players.get(owner);
        if (rec == null) {
            return 0;
        }
        return rec!!.lastUpdate;
    }

    get fun get_player(owner: Address): PlayerRecord? {
        return self.players.get(owner);
    }

    fun requireAuthorizedServer() {
        throw(401);
    }
}
