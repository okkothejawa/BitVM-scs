// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Block} from "../src/interfaces/IBridge.sol";
import "../src/libraries/Coder.sol";
import "./fixture/ConstantsFixture.sol";
import "../src/Storage.sol";
import "./Util.sol";

contract StorageTest is Test, ConstantsFixture {
    function testStorage_constructor_zeroDistance() public {
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockStepDistanceInvalid.selector, 0));
        new Storage(0, 0, hex"", 0, 0);
    }

    function testStorage_Submit_normal() public {
        IStorage _storage = new Storage(10, 832000, blockHash832000, 386101681, 1708879379);
        _storage.submit(block832001to832050, 832001);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 6);

        bytes4 expectedBits = bytes4(Endian.reverse32(386101681));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash832010, 0, expectedBits, 1708882338);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(832010);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_initialBlock() public {
        IStorage _storage = new Storage(10, 842562, blockHash842562, 386085339, 1715179752);
        _storage.submit(block842563to842612, 842563);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 6);

        bytes4 expectedBits = bytes4(Endian.reverse32(386085339));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash842592, 0, expectedBits, 1715194279);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(842592);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_step() public {
        IStorage _storage = new Storage(17, 841107, blockHash841107, 386085339, 1073676288);
        _storage.submit(block841108to841209, 841108);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 7);

        bytes4 expectedBits = bytes4(Endian.reverse32(386085339));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash841157, 0, expectedBits, 1714277734);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(841192);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_step2() public {
        IStorage _storage = new Storage(2, 832000, blockHash832000, 386101681, 1708879379);
        _storage.submit(block832001to832050, 832001);

        uint256 keyBlockCount = _storage.getKeyBlockCount();
        assertEq(keyBlockCount, 26);

        bytes4 expectedBits = bytes4(Endian.reverse32(386101681));
        IStorage.KeyBlock memory expectedKeyBlock = IStorage.KeyBlock(blockHash832002, 0, expectedBits, 1708880822);
        IStorage.KeyBlock memory actualKeyBlock = _storage.getKeyBlock(832002);
        assertEq(expectedKeyBlock.blockHash, actualKeyBlock.blockHash);
        assertEq(expectedKeyBlock.timestamp, actualKeyBlock.timestamp);
    }

    function testStorage_Submit_reorg() public {}

    function testStorage_Submit_zeroInput() public {
        IStorage _storage = new Storage(17, 841107, blockHash841107, 386085339, 1073676288);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(hex"", 841108);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(block841108to841209, 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.NoGivenBlockHeaders.selector));
        _storage.submit(hex"", 0);
    }

    function testStorage_Submit_lowHeight() public {
        uint256 initialHeight = 201;
        uint256 lowHeight = 201;
        IStorage _storage = new Storage(1, initialHeight, hex"", 0, 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooLow.selector, lowHeight - 1));
        _storage.submit(hex"ff", lowHeight);
    }

    function testStorage_Submit_notOnPace() public {
        uint256 height = 34;
        IStorage _storage = new Storage(17, 0, hex"", 0, 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightInvalid.selector, height));
        _storage.submit(hex"ff", height);
    }

    function testStorage_Submit_highHeight() public {
        uint256 initialHeight = 201;
        uint256 legitHeight = initialHeight + 1;
        uint256 highHeight = legitHeight + 1;
        IStorage _storage = new Storage(1, initialHeight, hex"", 0, 0);

        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooHigh.selector, highHeight, 0));
        _storage.submit(hex"ff", highHeight);

        uint256 step = 10;
        initialHeight = 832000;
        _storage = new Storage(step, initialHeight, blockHash832000, 386101681, 1708879379);
        _storage.submit(block832001to832050, 832001);

        legitHeight = initialHeight + (_storage.getKeyBlockCount() - 1) * step + 1;
        highHeight = legitHeight + step;
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHeightTooHigh.selector, highHeight, 5));
        _storage.submit(block832001to832050, highHeight);
    }

    function testStorage_Submit_invalidLength() public {
        IStorage _storage = new Storage(10, 832000, blockHash832000, 386101681, 1708879379);
        uint256 newLength = block832001to832050.length - 2;
        bytes memory corruptedData = Util.slice(block832001to832050, 0, newLength);

        vm.expectRevert(abi.encodeWithSelector(Coder.BlockHeaderLengthInvalid.selector, newLength));
        _storage.submit(corruptedData, 832001);
    }

    function testStorage_Submit_invalidHeaderCount() public {
        IStorage _storage = new Storage(10, 832000, blockHash832000, 386101681, 1708879379);
        uint256 newLength = block832001to832050.length - Coder.BLOCK_HEADER_LENGTH;
        bytes memory corruptedData = Util.slice(block832001to832050, 0, newLength);

        vm.expectRevert(
            abi.encodeWithSelector(IStorage.BlockCountInvalid.selector, newLength / Coder.BLOCK_HEADER_LENGTH)
        );
        _storage.submit(corruptedData, 832001);
    }

    function testStorage_Submit_differentHash() public {
        IStorage _storage = new Storage(2, 832000, blockHash832000, 386101681, 1708879379);
        vm.expectRevert(abi.encodeWithSelector(IStorage.BlockHashMismatch.selector, blockHash832000, blockHash842562));
        _storage.submit(block842563to842612, 832001);
    }

    // function testStorage_Submit_hashValueTooBig() public {
    //     IStorage _storage = new Storage(1, 832000, blockHash832000, 386101681, 1708879379);
    //     bytes memory corruptedData = Util.slice(block832001to832050, 0, Coder.BLOCK_HEADER_LENGTH);
    //     // make target too small
    //     corruptedData[72] = 0x00;
    //     corruptedData[73] = 0x00;
    //     corruptedData[74] = 0x00;
    //     corruptedData[75] = 0x03; // exponent byte
    //     bytes32 corruptedHash = Coder.toHash(corruptedData);

    //     vm.expectRevert(abi.encodeWithSelector(IStorage.HashNotBelowTarget.selector, corruptedHash, 0x0));
    //     _storage.submit(corruptedData, 832001);
    // }

    function testStorage_Submit_targetChangeOffLimit() public {
        IStorage _storage = new Storage(1, 832000, blockHash832000, 386101681, 1708879379);
        bytes memory corruptedData = Util.slice(block832001to832050, 0, Coder.BLOCK_HEADER_LENGTH);
        // make a small target
        corruptedData[72] = 0x00;
        corruptedData[73] = 0x00;
        corruptedData[74] = 0x00;
        corruptedData[75] = 0x03; // exponent byte

        vm.expectRevert(abi.encodeWithSelector(Coder.RetargetBeyondFactor4.selector));
        _storage.submit(corruptedData, 832001);
    }
}
