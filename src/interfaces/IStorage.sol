// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStorage {
    struct KeyBlock {
        bytes32 blockHash;
        uint256 accumulatedDifficulty;
        uint32 timestamp;
    }

    struct Epoch {
        bytes4 bits; // reversed order
        uint32 timestamp;
    }

    struct CheckBlockContext {
        uint256 accumulatedDifficulty;
        bytes32 prevHash;
        uint32 prevBlockTimestamp; // for retargeting calculation
        Epoch prevEpoch;
        uint256 prevEpochIndex;
    }

    event KeyBlocksSubmitted(uint256 tip, uint256 total, uint256 reorg);
    event ChainRetargeted(uint256 storedEpochsIndex, uint256 height, bytes4 newBits, uint32 timestamp, bool isReorg);

    error BlockStepDistanceInvalid(uint256 inputDistance);
    error BlockCountInvalid(uint256 inputLength);
    error BlockHeightTooLow(uint256 inputHeight);
    error BlockHeightInvalid(uint256 inputHeight);
    error BlockHeightTooHigh(uint256 inputHeight);
    error BlockHashMismatch(bytes32 expected, bytes32 actual);
    error BlockBitsMismatch(bytes4 expected, bytes4 actual);
    error ChainWorkNotEnough();
    error NoGivenBlockHeaders();
    error HashNotBelowTarget(bytes32 hash, bytes32 target);

    function submit(bytes calldata data, uint256 blockHeight) external;
    function getKeyBlock(uint256 blockHeight) external view returns (KeyBlock memory _block);
    function getNextKeyBlock(uint256 blockHeight) external view returns (KeyBlock memory _block);
    function getFirstKeyBlock() external view returns (KeyBlock memory _block);
    function getLastKeyBlock() external view returns (KeyBlock memory _block);
    function getKeyBlockCount() external view returns (uint256);

    function getEpoch(uint256 blockHeight) external view returns (Epoch memory _epoch);
    function getEpochCount() external view returns (uint256);
    function getFirstEpoch() external view returns (Epoch memory _epoch);
}
