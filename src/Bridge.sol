// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBridge.sol";
import "./EBTC.sol";
import "./libraries/ViewBTC.sol";
import "./libraries/ViewSPV.sol";
import "./libraries/Script.sol";
import {IStorage} from "./interfaces/IStorage.sol";
import {TransactionHelper} from "./libraries/TransactionHelper.sol";
import "./libraries/Coder.sol";
import "./interfaces/IStorage.sol";

contract Bridge is IBridge {
    EBTC ebtc;
    IStorage blockStorage;
    uint256 difficulty;
    bytes32 nOfNPubKey;

    using ViewBTC for bytes29;
    using ViewSPV for bytes32;
    using ViewSPV for bytes29;
    using ViewSPV for bytes4;
    using Script for bytes32;
    using Script for bytes;
    using TransactionHelper for bytes;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    /**
     * @dev withdrawer to pegOut
     */
    mapping(address withdrawer => PegOutInfo info) pegOuts;
    /**
     * @dev back reference from an pegOut to the withdrawer
     */
    mapping(bytes32 txId => mapping(uint256 vOut => address withdrawer)) usedUtxos;

    mapping(bytes32 txId => bool) pegIns;

    uint256 private constant PEG_OUT_MAX_PENDING_TIME = 8 weeks;

    bytes4 private version = 0x02000000;
    bytes4 private locktime = 0x00000000;

    constructor(EBTC _ebtc, IStorage _blockStorage, bytes32 _nOfNPubKey) {
        ebtc = _ebtc;
        blockStorage = _blockStorage;
        difficulty = Coder.bitToDifficulty(_blockStorage.getFirstEpoch().bits);
        nOfNPubKey = _nOfNPubKey;
    }

    function pegIn(address depositor, bytes32 depositorPubKey, ProofInfo calldata proof1, ProofInfo calldata proof2)
        external
    {
        if (isPegInExist(proof1.txId)) {
            revert PegInInvalid();
        }

        Output[] memory vout1 = proof1.rawVout.parseVout();
        Input[] memory vin2 = proof2.rawVin.parseVin();
        Output[] memory vout2 = proof2.rawVout.parseVout();

        if (vout1.length != 1 || vout2.length != 1) {
            revert InvalidVoutLength();
        }

        if (vin2.length != 1) {
            revert InvalidVinLength();
        }

        bytes32 taproot = nOfNPubKey.generateDepositTaprootAddress(depositor, depositorPubKey, 2);
        if (!vout1[0].scriptPubKey.equals(taproot.convertToScriptPubKey())) {
            revert InvalidScriptKey();
        }

        if (vin2[0].prevTxID != proof1.txId) {
            revert MismatchTransactionId();
        }

        bytes memory multisigScript = nOfNPubKey.generatePreSignScriptAddress();
        if (!vout2[0].scriptPubKey.equals(multisigScript)) {
            revert MismatchMultisigScript();
        }
        if (!isValidAmount(vout2[0].value)) {
            revert InvalidVoutValue();
        }
        if (!verifySPVProof(proof1) || !verifySPVProof(proof2)) {
            revert SpvCheckFailed();
        }

        ebtc.mint(depositor, vout2[0].value);

        pegIns[proof2.txId] = true;
    }

    function pegOut(
        string calldata destinationBitcoinAddress,
        Outpoint calldata sourceOutpoint,
        uint256 amount,
        bytes32 operatorPubkey
    ) external {
        if (!isValidAmount(amount)) {
            revert InvalidAmount();
        }
        if (pegOuts[msg.sender].status == PegOutStatus.PENDING) {
            revert PegOutInProgress();
        }
        if (usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut] != address(0)) {
            revert UtxoNotAvailable(
                sourceOutpoint.txId, sourceOutpoint.vOut, usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut]
            );
        }
        pegOuts[msg.sender] = PegOutInfo(
            destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey, block.timestamp, PegOutStatus.PENDING
        );
        usedUtxos[sourceOutpoint.txId][sourceOutpoint.vOut] = msg.sender;

        ebtc.transferFrom(msg.sender, address(this), amount);
        emit PegOutInitiated(msg.sender, destinationBitcoinAddress, sourceOutpoint, amount, operatorPubkey);
    }

    function burnEBTC(address withdrawer, ProofInfo calldata proof) external {
        PegOutInfo memory info = pegOuts[withdrawer];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }

        Output[] memory outputs = proof.rawVout.parseVout();
        if (outputs.length != 1) {
            revert InvalidPegOutProofOutputsSize();
        }
        if (
            !outputs[0].scriptPubKey.equals(
                Script.generatePayToPubKeyHashWithInscriptionScript(
                    info.destinationAddress, uint32(info.pegOutTime), withdrawer
                ).generateP2WSHScriptPubKey()
            )
        ) {
            revert InvalidPegOutProofScriptPubKey();
        }
        if (outputs[0].value != info.amount) {
            revert InvalidPegOutProofAmount();
        }
        bytes32 txId = ViewSPV.calculateTxId(
            version,
            proof.rawVin.ref(uint40(ViewBTC.BTCTypes.Vin)),
            proof.rawVout.ref(uint40(ViewBTC.BTCTypes.Vout)),
            locktime
        );
        if (proof.txId != txId) {
            revert InvalidPegOutProofTransactionId();
        }
        if (!verifySPVProof(proof)) {
            revert InvalidSPVProof();
        }

        delete pegOuts[withdrawer];
        ebtc.burn(address(this), info.amount);
        emit PegOutBurnt(withdrawer, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function refundEBTC() external {
        PegOutInfo memory info = pegOuts[msg.sender];
        if (info.status == PegOutStatus.VOID) {
            revert PegOutNotFound();
        }
        if (info.pegOutTime + PEG_OUT_MAX_PENDING_TIME > block.timestamp) {
            revert PegOutInProgress();
        }
        delete pegOuts[msg.sender];
        delete usedUtxos[info.sourceOutpoint.txId][info.sourceOutpoint.vOut];
        ebtc.transfer(msg.sender, info.amount);
        emit PegOutClaimed(msg.sender, info.sourceOutpoint, info.amount, info.operatorPubkey);
    }

    function verifySPVProof(ProofInfo memory proof) internal view returns (bool) {
        bytes29 header = proof.header.ref(uint40(ViewBTC.BTCTypes.Header));
        bytes32 merkleRoot =
            ViewBTC.getMerkle(proof.txId, proof.merkleProof.ref(uint40(ViewBTC.BTCTypes.MerkleArray)), proof.index);
        if (header.merkleRoot() != merkleRoot) {
            revert MerkleRootMismatch();
        }
        if (!header.checkWork(header.target())) {
            revert DifficultyMismatch();
        }

        bytes32 prevHash = blockStorage.getKeyBlock(proof.blockHeight).blockHash;
        bytes29 parentHeader = abi.encodePacked(proof.parents, proof.header).ref(uint40(ViewBTC.BTCTypes.HeaderArray));
        parentHeader.checkChain();
        if (
            proof.parents.ref(uint40(ViewBTC.BTCTypes.HeaderArray)).indexHeaderArray(0).workHash()
                != bytes32(Endian.reverse256(uint256(prevHash)))
        ) {
            revert PreviousHashMismatch();
        }

        bytes32 nextHash = blockStorage.getNextKeyBlock(proof.blockHeight).blockHash;
        bytes29 childHeader = abi.encodePacked(proof.header, proof.children).ref(uint40(ViewBTC.BTCTypes.HeaderArray));
        childHeader.checkChain();
        if (
            childHeader.indexHeaderArray(childHeader.len() / 80 - 1).workHash()
                != bytes32(Endian.reverse256(uint256(nextHash)))
        ) {
            revert NextHashMismatch();
        }

        // 3. Accumulated difficulty
        uint256 difficulty1 = blockStorage.getNextKeyBlock(proof.blockHeight).accumulatedDifficulty;
        uint256 difficulty2 = blockStorage.getLastKeyBlock().accumulatedDifficulty;
        uint256 accumulatedDifficulty = difficulty2 - difficulty1;
        if (accumulatedDifficulty <= difficulty) {
            revert InsufficientAccumulatedDifficulty();
        }

        return true;
    }

    function isPegInExist(bytes32 txId) internal view returns (bool) {
        return pegIns[txId];
    }

    /**
     * @dev checks any given number is a power of 2
     */
    function isValidAmount(uint256 n) internal pure returns (bool) {
        (n != 0) && ((n & (n - 1)) == 0);
        return true;
    }
}
