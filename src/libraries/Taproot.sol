// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma experimental ABIEncoderV2;

import "./EllipticCurve.sol";

library Taproot {
    error InvalidCompressedPublicKey();

    using EllipticCurve for uint256;

    uint256 private constant SECP256K1_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    uint256 private constant SECP256K1_A = 0;
    uint256 private constant SECP256K1_B = 7;
    uint256 private constant SECP256K1_GX = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    uint256 private constant SECP256K1_GY = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;
    uint8 private constant LEAF_VERSION_TAPSCRIPT = 0xc0;
    uint256 private constant COMPRESSED_PUBLICK_KEY_LENGTH = 33;

    function toXOnly(bytes calldata pubKey) public pure returns (bytes32 xOnly, bytes1 parity) {
        if (pubKey.length != COMPRESSED_PUBLICK_KEY_LENGTH) {
            revert InvalidCompressedPublicKey();
        }
        xOnly = bytes32(pubKey[1:COMPRESSED_PUBLICK_KEY_LENGTH]);
        parity = pubKey[0];
    }

    function taggedHash(string memory tag, bytes memory m) internal pure returns (bytes32) {
        bytes32 tagHash = sha256(abi.encodePacked(tag));
        return sha256(abi.encodePacked(tagHash, tagHash, m));
    }

    function tapleafTaggedHash(bytes memory script) internal pure returns (bytes32) {
        bytes memory scriptPart = abi.encodePacked(LEAF_VERSION_TAPSCRIPT, prependCompactSize(script));
        return taggedHash("TapLeaf", scriptPart);
    }

    function tapbranchTaggedHash(bytes32 thashedA, bytes32 thashedB) internal pure returns (bytes32) {
        if (thashedA < thashedB) {
            return taggedHash("TapBranch", abi.encodePacked(thashedA, thashedB));
        } else {
            return taggedHash("TapBranch", abi.encodePacked(thashedB, thashedA));
        }
    }

    function prependCompactSize(bytes memory data) internal pure returns (bytes memory) {
        if (data.length < 0xfd) {
            return abi.encodePacked(uint8(data.length), data);
        } else if (data.length <= 0xffff) {
            return abi.encodePacked(uint8(0xfd), uint16(data.length), data);
        } else if (data.length <= 0xffffffff) {
            return abi.encodePacked(uint8(0xfe), uint32(data.length), data);
        } else {
            return abi.encodePacked(uint8(0xff), uint64(data.length), data);
        }
    }

    function createTaprootAddress(bytes32 internalKey, uint8 parity, bytes[] memory scripts)
        public
        pure
        returns (bytes32)
    {
        bytes32 merkleRootHash = merkleRoot(scripts);

        bytes32 tweak = taggedHash("TapTweak", abi.encodePacked(internalKey, merkleRootHash));
        uint256 tweakInt = uint256(tweak);

        // Convert internalKey to elliptic curve point
        (uint256 px, uint256 py) = publicKeyToPoint(internalKey, parity);

        // Compute H(P|c)G
        (uint256 gx, uint256 gy) = EllipticCurve.ecMul(tweakInt, SECP256K1_GX, SECP256K1_GY, SECP256K1_A, SECP256K1_P);

        // Compute Q = P + H(P|c)G
        (uint256 qx,) = EllipticCurve.ecAdd(px, py, gx, gy, SECP256K1_A, SECP256K1_P);

        // Convert the resulting point back to bytes32
        bytes32 outputKey = bytes32(qx);

        return outputKey;
    }

    function publicKeyToPoint(bytes32 pubKey, uint8 parity) internal pure returns (uint256, uint256) {
        uint256 x = uint256(pubKey);
        uint256 y = EllipticCurve.deriveY(parity, x, SECP256K1_A, SECP256K1_B, SECP256K1_P);
        return (x, y);
    }

    function merkleRoot(bytes[] memory scripts) internal pure returns (bytes32) {
        if (scripts.length == 0) {
            return bytes32(0);
        }

        if (scripts.length == 1) {
            bytes32 tapLeaf = tapleafTaggedHash(scripts[0]);
            return tapLeaf;
        }

        if (scripts.length == 2) {
            bytes32 left = tapleafTaggedHash(scripts[0]);
            bytes32 right = tapleafTaggedHash(scripts[1]);
            return tapbranchTaggedHash(left, right);
        } else {
            bytes32[] memory hashes = new bytes32[](scripts.length);
            for (uint256 i; i < scripts.length; ++i) {
                hashes[i] = tapleafTaggedHash(scripts[i]);
            }
            while (hashes.length > 1) {
                uint256 newLength = (hashes.length + 1) / 2;
                bytes32[] memory newHashes = new bytes32[](newLength);
                uint256 j;
                for (uint256 i; i < hashes.length; i += 2) {
                    if (i + 1 < hashes.length) {
                        newHashes[j] = tapbranchTaggedHash(hashes[i], hashes[i + 1]);
                    } else {
                        newHashes[j] = hashes[i];
                    }
                    j++;
                }
                hashes = newHashes;
            }
            return hashes[0];
        }
    }
}
