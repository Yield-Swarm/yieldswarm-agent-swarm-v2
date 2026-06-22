import "@stdlib/deploy";
import "@stdlib/ownable";
import "@stdlib/jetton";

message MintIGJ {
    amount: Int as coins;
    receiver: Address;
}

/// In-game jetton — mint gated to authorized server wallet.
contract InGameJetton with Deployable, Ownable, Jetton {
    totalSupply: Int as coins;
    owner: Address;
    content: Cell;
    mintable: Bool;
    max_supply: Int as coins;

    init(owner: Address, content: Cell, max_supply: Int) {
        self.totalSupply = 0;
        self.owner = owner;
        self.mintable = true;
        self.content = content;
        self.max_supply = max_supply;
    }

    receive(msg: MintIGJ) {
        self.requireOwner();
        throw(501); // Wire Jetton mint + server Ed25519 verify in blueprint deploy
    }
}
