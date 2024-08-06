// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./fixture/StorageFixture.sol";
import "../src/Bridge.sol";
import "../src/libraries/TransactionHelper.sol";
import "./Util.sol";

contract PegOutTest is StorageFixture {
    function testPegOut_buildStorage() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        IStorage _storage = IStorage(fixture._storage);
        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, headers01.length / Coder.BLOCK_HEADER_LENGTH / step01 + 1);

        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(keyHash01, 0, keyTime01);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(keyHeight01);
        IStorage.KeyBlock memory actualKeyBlock2 = _storage.getKeyBlock(keyHeight01 + step01 - 1);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock2.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock2.timestamp);
    }

    function testPegOut_pegOut_normal() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        StorageSetupResult memory fixture = buildStorage(initNormal);

        Bridge bridge = Bridge(fixture.bridge);
        address withdrawer = fixture.withdrawer;
        address operator = fixture.operator;
        ProofParam memory proofParam = getPegOutProofParamNormal();
        ProofInfo memory proof = Util.paramToProof(proofParam, true);

        string memory withdrawerAddr = Util.generateAddress(WITHDRAWER_PUBKEY, Util.P2PKH_TESTNET);
        vm.warp(1722328130);
        vm.startPrank(withdrawer);
        bridge.pegOut(withdrawerAddr, Outpoint(hex"1234", 0), 100000, OPERATOR_PUBKEY);
        vm.stopPrank();

        vm.prank(operator);
        bridge.burnEBTC(withdrawer, proof);
    }

    function testPegOut_pegOut_insufficientAccumulatedDifficulty() public {
        StorageSetupInfo memory initNormal = getPegOutSetupInfoNormal();
        ProofParam memory proofParam = getPegOutProofParamNormal();
        uint256 nextKeyBlockIndex = (proofParam.blockHeight - initNormal.height) / initNormal.step + 1;
        uint256 nextKeyBlockHeight = initNormal.step * nextKeyBlockIndex + initNormal.height;
        uint256 insufficientStorageLength = (nextKeyBlockHeight - initNormal.height) * Coder.BLOCK_HEADER_LENGTH;
        initNormal.headers = Util.slice(initNormal.headers, 0, insufficientStorageLength);
        StorageSetupResult memory fixture = buildStorage(initNormal);

        Bridge bridge = Bridge(fixture.bridge);
        address withdrawer = fixture.withdrawer;
        address operator = fixture.operator;
        ProofInfo memory proof = Util.paramToProof(proofParam, true);

        string memory withdrawerAddr = Util.generateAddress(WITHDRAWER_PUBKEY, Util.P2PKH_TESTNET);
        vm.warp(1722328130);
        vm.startPrank(withdrawer);
        bridge.pegOut(withdrawerAddr, Outpoint(hex"1234", 0), 100000, OPERATOR_PUBKEY);
        vm.stopPrank();

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IBridge.InsufficientAccumulatedDifficulty.selector));
        bridge.burnEBTC(withdrawer, proof);
    }
}
