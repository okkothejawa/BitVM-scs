// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/EBTC.sol";
import "../../src/Storage.sol";
import "../utils/Util.sol";
import "../mockup/BridgeTestnet.sol";
import {TestData} from "./TestData.sol";

struct StorageSetupInfo {
    uint256 step;
    uint256 height;
    bytes32 blockHash;
    uint32 bits;
    uint32 timestamp;
    uint32 epochTimestamp;
    uint256 startHeight;
    bytes headers;
}

struct StorageSetupResult {
    address _storage;
    address bridge;
    address ebtc;
    address owner;
    address withdrawer;
    address depositor;
    address operator;
    address submitter;
}

contract StorageFixture is Test {
    uint256 constant DEFAULT_STEP = 10;
    bytes32 constant N_OF_N_PUBKEY = 0x8b839569cde368894237913fe4fbd25d75eaf1ed019a39d479e693dac35be19e;
    bytes32 constant OPERATOR_PUBKEY = 0x58f54b8ba6af3f25b9bafaaf881060eafb761c6579c22eab31161d29e387bcc0;
    bytes constant WITHDRAWER_PUBKEY = hex"02f80c9d1ef9ff640df2058c431c282299f48424480d34f1bade2274746fb4df8b";
    bytes32 constant DEPOSITOR_PUBKEY = hex"edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b";

    address owner = vm.addr(1);
    address withdrawer = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address depositor = vm.addr(3);
    address operator = vm.addr(4);
    address submitter = vm.addr(5);

    TestData data = new TestData();

    function _buildStorage(StorageSetupInfo memory params, bool useDataFile)
        public
        returns (StorageSetupResult memory)
    {
        address _withdrawer = useDataFile ? data.withdrawer() : withdrawer;

        vm.deal(owner, 100 ether);

        vm.prank(owner);
        IStorage _storage = new Storage(
            params.step,
            params.height,
            IStorage.KeyBlock(params.blockHash, 0, params.timestamp),
            IStorage.Epoch(bytes4(Endian.reverse32(params.bits)), params.epochTimestamp)
        );
        vm.prank(submitter);
        _storage.submit(params.headers, params.startHeight);

        vm.startPrank(owner);
        EBTC ebtc = new EBTC(address(0));
        Bridge bridge = new BridgeTestnet(ebtc, _storage, N_OF_N_PUBKEY, 1);
        ebtc.setBridge(address(bridge));
        vm.stopPrank();

        vm.startPrank(address(bridge));
        ebtc.mint(_withdrawer, 100 ** ebtc.decimals());
        vm.stopPrank();

        vm.prank(_withdrawer);
        ebtc.approve(address(bridge), type(uint256).max);

        return StorageSetupResult({
            _storage: address(_storage),
            bridge: address(bridge),
            ebtc: address(ebtc),
            owner: owner,
            withdrawer: _withdrawer,
            depositor: depositor,
            operator: operator,
            submitter: submitter
        });
    }

    function buildStorage(StorageSetupInfo memory params) public returns (StorageSetupResult memory) {
        return _buildStorage(params, false);
    }

    function buildStorageFromDataFile(StorageSetupInfo memory params) public returns (StorageSetupResult memory) {
        return _buildStorage(params, true);
    }

    function getNormalSetupInfo() public view returns (StorageSetupInfo memory) {
        return StorageSetupInfo(step00, height00, initHash00, bits00, time00, epochTime00, height00 + 1, headers00);
    }

    function getPegInProofParamNormal(uint256 index) public pure returns (ProofParam memory) {
        ProofParam memory proofParam = ProofParam({
            merkleProof: hex"",
            parents: hex"00000020dd8cede9a3fa7ff6a721c74fe4b3445edc723ed007137d354206f1754d010000f4fe7ee7943dd2a1f41e7b4b14d7857f311c7fdabc466bf346137937a94fa972b259cb66ae77031e81c5490000000020fa087619d17a6ece840fe2f76b3cf6edb762b42eebd8b41ab188fb5da900000017508e1323c658a9fd8e68bf1a04431b138f871fa20f63288e03d4bffbb90d61d159cb66ae77031eab19640000000020ed3ab8d3d9d241b67eed8ccaa12e2925bc61e2ee5c7bf074ea7f2338ce0100001c8e70fbaf756d678712cdc07e3a196cf4a21e6dfcdc3e47dc8a4b16f58b1b19f059cb66ae77031e44e21b0000000020f845d28900a049be092a5180d4c7a2329573aa3744d30d98b4400a6a6802000082876a2f9b3b1088acce2503d058703e1c72ab7124fea8d396d62cd0d09aa9fc0f5acb66ae77031ea2fca400000000202da99023d44993fc26f465ed97e69e6b0e722b9e718d768a687463d8230100001614fa2a5155a00cc55f3bdc5620615fab17101307d24fa9af0a96895fab69ab2f5acb66ae77031eb6c61100000000202fdcbdd914e68cee8c21607ea0e7b997de6e607fd15ae6389e3b5c3b52010000da2716449ff73258368618d6fcd05c718dae42040c2a2c825b518444936faddd4d5acb66ae77031e802660000000002080e595ab5b33b3a3030b95f4d7bcd81fa95afef2942ef36e82ffc71bdd00000095ed16e21c4978b07daf16afe447abd27d1d2863ef4903e2e243db2dcb3651886c5acb66ae77031e6cd37d0000000020934ee22d4157f24e376804018b4855f50739807eb89641d301fd8525e3010000cf0a12c0959af8b40bf2f1f4ba5f50c25de9d686061aea03882cc75c09d016d58c5acb66ae77031ecd58000000000020d8208123d0d5bcbdd14ac6748d39b38369627d7b1b5d083a96de1e2303020000b665bb85bff864eec01a45c1ee7cfbe4baf3061cd0eea9c540dbc69ce6cee364aa5acb66ae77031e99e41300",
            children: hex"000000208b1223c61e0b89b2237c0b109f52504817f675d3721c39074132c1ac20030000776752a1c881082b866119e3d64af28b1a0b35e9aae9df0cd3f6c58547573ba2e75acb66ae77031e5ee62b00",
            rawTx: hex"",
            index: 0,
            blockHeight: 1375639,
            blockHeader: hex"00000020a928d2593b8c7a3cac11005527eb56e4d130eccce1a298c4cbba1105980000003cb77c39a262c132fa5520500fb174e64b8968a4649037461a18e570fcf84b05c95acb66ae77031e01680500"
        });
        if (index == 1) {
            proofParam.rawTx =
                hex"0200000000010106ad8ef8fb63d196323229e860a2093f06ce21fb04746da1d39512c9446fba820000000000ffffffff01e803020000000000225120963b0923fd7a825e0333c4bf71c218a86f85504576ddb777f65d9c5a1e4587c0024730440220665bf19ca3897d1513f32a530a614ba0cedf906e018b3cdd4b6df653e3c0ba9a02201bc805a33e91dbe2e89330398c8087dae8c734a751e8f271ac2aecd3c9f4ff8601232102edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac00000000";
            proofParam.index = 1;
            proofParam.merkleProof =
                hex"391e76f39300e9fe227420d7c09a628667495ccb5ec9dea543979f85fa8a95464ddd886d47e6d22fac0a5d53038cb8a5731f738f12fc35074e84d6be5f170d04";
        }
        if (index == 2) {
            proofParam.rawTx =
                hex"02000000000101b74cae721235d04452ba979c459e4ee797dffed246593dbdf378f540592197460000000000ffffffff01000002000000000022512002374a04da115575f05a4f1e12f84d89c0fb25cc7620795c31b93d3efff817e404411d8e142dcd43b38741f1cef187ed17d7b7152e4e7db3d7fb33f36116b07daf8d5a1bec333adbad7306ea8c900330d379d7faa48cbc8258b4490ec027cccd4349014172ba02fcfaea13169e24682d5b813bd58fe3df3735a2f59a057ff06829c5d5b7e1b3ccea53fbbb4a8bbe89657d1858e2b10eb78bb18004545bdf4f0bdc2523e5017200632a30784444644464644464446464644444646444446464444444446444644444644444644444444444446468208b839569cde368894237913fe4fbd25d75eaf1ed019a39d479e693dac35be19ead20edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301bac41c1edf074e2780407ed6ff9e291b8617ee4b4b8d7623e85b58318666f33a422301b2ac235214c9b16e9bd0dcc8146c16a10148285e8be3be80dc37ace561176f76400000000";
            proofParam.index = 2;
            proofParam.merkleProof =
                hex"724c2db16b900af46e03af35c362c602f0078b8732a259e7fd1ad243e82fdc8b621e72139936e159cc1f620a5566ae505c28afa882b8f8f5262924c11638b96b";
        }

        return proofParam;
    }

    function getPegOutSetupInfoNormal() internal view returns (StorageSetupInfo memory setupInfo) {
        return StorageSetupInfo(step01, height01, initHash01, bits01, time01, epochTime01, height01 + 1, headers01);
    }

    function getPegOutProofParamNormal() internal pure returns (ProofParam memory proofParam) {
        proofParam = ProofParam({
            merkleProof: hex"c2dc8f39c9c20a40ccf47fdf999a245c85bb97640a4ccf8ae7801c276a169eaaa3b607b17d587db693957567d8ec4938705acd7a8d0eba78a5b2d561d3a88231",
            parents: hex"00000020dae05a49944ed82b0af0748ac7a550f93784f8abc69f4983d4bef24c7c02000061805b597a6fbbfa3de00e4ba6ce3f09cfe2cc850799d699739fabe344bb0a104f65bc66ae77031e8606200000000020e3e6864e854538ce28c9502df07fff11ebf6e27570abc3fdc09153bf27020000150577da69a9e455e38b08fd361d00de12deaa5d0db6fd45176a3e2ec27f3f9c6d65bc66ae77031e6bd934000000002004ba189b13eaaaeefa5605ea12745bcaca2dc744344435b66481624278000000b4526d11a8d129a90ea31b6a2c5dece1b51c3dc9098fa497a69716f0c7fc2ba08c65bc66ae77031eafb00500000000207c697438c81caaba37f7b7c4dd6ae5cdfbe0f6f3261c033ec2af66d93202000055cc628f59600a75049214845165d1269dae55f0dd9b0e729f4013a94175e01caa65bc66ae77031e97ef1000000000208ee24f4bbd387e49206aaa3750b25ebc2fc49ad08e018c4e3e833e55bf0200003e27219d3dbebd2f01f2b49293ab1145c18374802d98172f4bec927c6479c8c2c865bc66ae77031e6d7f3b0000000020f94b0be310172cafda95fee6f982f7297e811b52c8427e35fa1ff19e28010000b8d4900f87f4f8403c1d902f3a1eb68729766764ed737b1d6135227045bfded6e765bc66ae77031ecc632c00",
            children: hex"000000207a3f4f66b199ed4609f2308ca900c3033e47b995541a382e694cd06a68000000a18f3068afa0369702c7f7eb1dc1530ad37e7a1c34d91d4cbeb50d8bd0ef348f2566bc66ae77031e17eb1100000000200d3e8899704709f64729d88e01310eca126c2193b2c7e8cc03bdd658ef010000a445ec1f2291fc04e13287542dbb2ee9e1886de8def92f10dd1df0f98c6765ba4366bc66ae77031edd01440000000020da283c6b906e496e90ac9c7aa5527b582bd54b042e6ebb26b4a3ba3c3d0200003dbe8a9bc19f6d4aed4ab42c74babcefb61c1316f348895f067970b8d75c23506266bc66ae77031ef3ba2d0000000020418de557ee6f030c1db99434ce1494b215611cc6e18c6edec435847b82000000a8a09f7524db35b073d863c7a81dc406f4312c0703b175a00acdbadeb8d037e78166bc66ae77031ed2081f00",
            rawTx: hex"02000000000101fe8fa7750ead33ec74d91919cbce4d0244620f2c0d7f74fa97199723efc0a0e60000000000ffffffff0100000200000000002200204f82b133a5c31fd6f3b4199be2b776b7cdd9803f2e1c1848d932ee3cdd2ca52102483045022100c0d96c09fd25b6d6d8eca8ce78126d5f543307d7211a06d057a7d376f132ca630220308c0f94bc2713fdc55fca14edec9e12d28947d0abd0cb7c728be189dda700740123210358f54b8ba6af3f25b9bafaaf881060eafb761c6579c22eab31161d29e387bcc0ac00000000",
            index: 2,
            blockHeight: 1344016,
            blockHeader: hex"00000020dbbfcb1edc721feb564017fde290e2ee8578496bf893b57f870a7b7637020000838da30d12af3fb32933d00116d5cf9566705030f0f6fc913b79db34ed4f4be40666bc66ae77031e25af2800"
        });
    }

    uint256 step00 = DEFAULT_STEP;
    uint256 height00 = 1375620;
    uint32 bits00 = 503543726;
    uint32 time00 = 1724602487;
    uint32 epochTime00 = 1724580577;
    bytes32 constant initHash00 = hex"00000230a834370a29c5d3fd3fc5f77afe208327bcdf98a9715295e1598978be";
    bytes constant headers00 =
        hex"00000020be788959e1955271a998dfbc278320fe7af7c53ffdd3c5290a3734a830020000e9412611956266e449e55dd1904c6d9afbe03ec023c7ffbce022829e8049384a9858cb66ae77031e347d010000000020efc0cea8068a0192448e3ef7a75f7ce9a4f69c3c1a4ef82b38b7a5b18d010000a135ff9681ce7ed569a73ec5af9425dca007a0fdf7663b32a983dbce11447900b658cb66ae77031e355f46000000002012885486ca9e18b5ebdf2878fe7187e2413e635273b5759267350adbd301000097a2b3dc760761e50a2cbfa10fa8617673e1444ea7797f4a71bdc48513930e39d558cb66ae77031efa26690000000020d738a5c803bd9bfca23f0a466771e76e3d88686fb916958be8b81ac67501000083de8439d535f3b3b683848de2bda18698a4da0aaf5940a03cdfddcd6bbd0446f458cb66ae77031ec09bea00000000204031f1d2e9b157e759a083b617780518efb62730df10f87862ff0e02750200005d0151ed0fd688a86bbd4c882d62a896200427eb8e9487d7486ec715982119831559cb66ae77031e19bf060100000020c2aaf3428d7828ced7e6ec998ef4eb185a085cb7b9dd4d916dc0701ba0000000a47456eff6284434f69e6e8646217225ac940a5e6cb46c0e6aa9b6900aed11aa3659cb66ae77031e23e56b0000000020b7f4dc9327278f5c4c7dbaf65a2d70d3a0cae22ef5120f88d52a59314b000000c84b44dc36c07cfdd34b98069218332e1c27675ee588fbf445841e1e8c86ad8c5659cb66ae77031ec949220000000020e7e59d4fa4e159048da6be01e5e0f6703ebb84a4c2d44b1962a523649201000070d2e7b2142e6718799e121f97ca9b305cab246c38701a4b8bae9d9d76f545c27459cb66ae77031eb8115e0000000020ed319e5afdb31c97de72a8fd6afbd6564cbcc2af0f390fd7af331fc5ec0000001f2b25e5a59a63b16565d8be2cd08a6595ab187fdf85ca7e4fc67a8540841e7c9359cb66ae77031eb981370000000020dd8cede9a3fa7ff6a721c74fe4b3445edc723ed007137d354206f1754d010000f4fe7ee7943dd2a1f41e7b4b14d7857f311c7fdabc466bf346137937a94fa972b259cb66ae77031e81c5490000000020fa087619d17a6ece840fe2f76b3cf6edb762b42eebd8b41ab188fb5da900000017508e1323c658a9fd8e68bf1a04431b138f871fa20f63288e03d4bffbb90d61d159cb66ae77031eab19640000000020ed3ab8d3d9d241b67eed8ccaa12e2925bc61e2ee5c7bf074ea7f2338ce0100001c8e70fbaf756d678712cdc07e3a196cf4a21e6dfcdc3e47dc8a4b16f58b1b19f059cb66ae77031e44e21b0000000020f845d28900a049be092a5180d4c7a2329573aa3744d30d98b4400a6a6802000082876a2f9b3b1088acce2503d058703e1c72ab7124fea8d396d62cd0d09aa9fc0f5acb66ae77031ea2fca400000000202da99023d44993fc26f465ed97e69e6b0e722b9e718d768a687463d8230100001614fa2a5155a00cc55f3bdc5620615fab17101307d24fa9af0a96895fab69ab2f5acb66ae77031eb6c61100000000202fdcbdd914e68cee8c21607ea0e7b997de6e607fd15ae6389e3b5c3b52010000da2716449ff73258368618d6fcd05c718dae42040c2a2c825b518444936faddd4d5acb66ae77031e802660000000002080e595ab5b33b3a3030b95f4d7bcd81fa95afef2942ef36e82ffc71bdd00000095ed16e21c4978b07daf16afe447abd27d1d2863ef4903e2e243db2dcb3651886c5acb66ae77031e6cd37d0000000020934ee22d4157f24e376804018b4855f50739807eb89641d301fd8525e3010000cf0a12c0959af8b40bf2f1f4ba5f50c25de9d686061aea03882cc75c09d016d58c5acb66ae77031ecd58000000000020d8208123d0d5bcbdd14ac6748d39b38369627d7b1b5d083a96de1e2303020000b665bb85bff864eec01a45c1ee7cfbe4baf3061cd0eea9c540dbc69ce6cee364aa5acb66ae77031e99e4130000000020a928d2593b8c7a3cac11005527eb56e4d130eccce1a298c4cbba1105980000003cb77c39a262c132fa5520500fb174e64b8968a4649037461a18e570fcf84b05c95acb66ae77031e01680500000000208b1223c61e0b89b2237c0b109f52504817f675d3721c39074132c1ac20030000776752a1c881082b866119e3d64af28b1a0b35e9aae9df0cd3f6c58547573ba2e75acb66ae77031e5ee62b0000000020d650dea9bb03b387cf06b24a85cf371da0ec09e3526b82bee1e204933603000012a803031f82f3ebecea2f8232fff9a3ec36e3f8ce0de5ef609c88616502b9d5055bcb66ae77031ed9747a00000000204b03255159d818beef706c867a01afd4641a567817092d1875bc33551c0000004c2c8e9ae7fd896b52846f0aa2b112e6678826baf514f3c55d2aa6f23de8336d255bcb66ae77031e00814e0000000020ae12410b1dea6bccb3dfce4f400cfc870c8f3847633dc7e10697dbe552010000853617e525dcb718d8dc61c186d4e6789742b5e2463c69d5fe54c46527099005445bcb66ae77031ec074440000000020f264ec03527bd41084d099ea5ed7e567cb23d0430af85655be2771418d02000078da46a9ecf6d1423c9be76c5c30d9e91ef48b1bd1f983bf90e774f0271eb625635bcb66ae77031ea2eb7b00000000208cae72271a066469712a8a87914a056cd957f627169b343778f778254e000000eea7d233b540df49f53f89016ade18eab7e633513286b666444113cb62f55d03825bcb66ae77031e05b50c0000000020d7c3c0711e04bcc686fa6104a22f46e08672d698c2b42d2282354c9f6c030000ca11d4ebf2f094a8dba7f4ee77fd9b98d29144031fed4b964cf922ed2b7754dca15bcb66ae77031e99ce5e00000000207ed5d9612b1edf2fd290bc257961c7df20d2af39977c509ca179b2515c02000035ed8f392e32377c642b33be7d27677744f5fe2c11d956944438a64f3f6ae669c05bcb66ae77031e11f90800000000204ba950215562072d474e4bcfc671e6ce2aa65836bb9b5799063d6b7ab601000040e578f31edeec42c3ff014dc5ec7736920e223bfb6c7d44f879f5b36886260ade5bcb66ae77031e42e5040000000020889dab578614f2b8313c644a944c793526482d87ef49393c17e6979ad7020000a0ec1c5e73f6982da456932d66c24caeb20b044fe3236d8cb2358457b742f55dfc5bcb66ae77031e2f240600000000204c5fd20034970c6c750b439703b3fd41a4423e7386cb93130f01bb032e0200009afaa7ddc8ef40b498b866542e802b3d60c61e9e35151d40648790b4831735021a5ccb66ae77031e219b2100";
    // first keyBlock(init height + step) hash
    bytes32 constant keyHash00 = hex"000000a95dfb88b11ab4d8eb2eb462b7edf63c6bf7e20f84ce6e7ad1197608fa";
    uint32 keyTime00 = 1724602802;

    uint256 step01 = DEFAULT_STEP;
    uint256 height01 = 1344000;
    uint32 bits01 = 503543726;
    uint32 time01 = 1723622427;
    uint32 epochTime01 = 1723580734;
    bytes32 constant initHash01 = hex"000000ee5cfcb244a2c2c2d3353e1f3e176bf52102c2597851c75114459de847";
    bytes constant headers01 =
        hex"0000002047e89d451451c7517859c20221f56b173e1f3e35d3c2c2a244b2fc5cee000000a63b096540f7e31ff020a8091791d0a8fe5964cff415a6b84a798b719adfad513a64bc66ae77031e5a461f000000002098e12d2aca6c9e3e87dde3ff682af5b32f81f8cc930f40475a90bc7d620000000871d98c89130c7db2f2147051ad9812fd33d3f6197eaba6b1e08adc051e5c185864bc66ae77031e8d9c060000000020ad3aa41db31a75396a4d0b14fe05c24f8b0e315faf81282984485f60640200000af0b225905de2af8ba8e59beb510f0691a2841201b2dad2181075b6baa504fd7664bc66ae77031ee0d47a0000000020be088d799b3c9244e4663bdc29de4a5c521e1857203a687e0f43c3575c020000a889f42da334f16fa3d9b8126c2b2a4a8c7e3dade6007adb21e8707d696ffdfb9664bc66ae77031eefe31d000000002016e295a03647bfb46e3e9e99555a83019a5d9c4d288441babf4e3fce1501000007999ebba630c8d694e6ac212d39d96ba87b314d8b44ff1cb6225546fb4071dab564bc66ae77031eeb530c0000000020f667013c266a093c1bdc80e1a82b1fea32ac89bcb0bdf50f1168d2d1d8010000640fefc56652267f280e861b14380649fb863bb6fd491bcb09eff27e49114882d364bc66ae77031eacde5c0000000020cdf26c2166e3b22aa6a64cdb6cd56f1839f8388340c1437336e069d97c0100006a9ce1c08ec194b83e8554dfd5a96268e3c24b892717d2001ef28fe7ad746818f264bc66ae77031ef0672500000000205a70512cb0fa016ec3104735ba137fd3a491234151a1bcbc9073fd072f000000cd9f32385c9c6a6c65a38af56230a43839245801d1ed7ac9cadd83b47bd976fb1165bc66ae77031e001e2f0000000020371ac622daca963def5bc6e8643bd0d0bcebb269fba69b4067eba10c7001000053b59c0c4b81d02d90162c168f5919ed29b471d3e7a486b3c6bc5b3b2f6bafbd2f65bc66ae77031e990b660000000020dae05a49944ed82b0af0748ac7a550f93784f8abc69f4983d4bef24c7c02000061805b597a6fbbfa3de00e4ba6ce3f09cfe2cc850799d699739fabe344bb0a104f65bc66ae77031e8606200000000020e3e6864e854538ce28c9502df07fff11ebf6e27570abc3fdc09153bf27020000150577da69a9e455e38b08fd361d00de12deaa5d0db6fd45176a3e2ec27f3f9c6d65bc66ae77031e6bd934000000002004ba189b13eaaaeefa5605ea12745bcaca2dc744344435b66481624278000000b4526d11a8d129a90ea31b6a2c5dece1b51c3dc9098fa497a69716f0c7fc2ba08c65bc66ae77031eafb00500000000207c697438c81caaba37f7b7c4dd6ae5cdfbe0f6f3261c033ec2af66d93202000055cc628f59600a75049214845165d1269dae55f0dd9b0e729f4013a94175e01caa65bc66ae77031e97ef1000000000208ee24f4bbd387e49206aaa3750b25ebc2fc49ad08e018c4e3e833e55bf0200003e27219d3dbebd2f01f2b49293ab1145c18374802d98172f4bec927c6479c8c2c865bc66ae77031e6d7f3b0000000020f94b0be310172cafda95fee6f982f7297e811b52c8427e35fa1ff19e28010000b8d4900f87f4f8403c1d902f3a1eb68729766764ed737b1d6135227045bfded6e765bc66ae77031ecc632c0000000020dbbfcb1edc721feb564017fde290e2ee8578496bf893b57f870a7b7637020000838da30d12af3fb32933d00116d5cf9566705030f0f6fc913b79db34ed4f4be40666bc66ae77031e25af2800000000207a3f4f66b199ed4609f2308ca900c3033e47b995541a382e694cd06a68000000a18f3068afa0369702c7f7eb1dc1530ad37e7a1c34d91d4cbeb50d8bd0ef348f2566bc66ae77031e17eb1100000000200d3e8899704709f64729d88e01310eca126c2193b2c7e8cc03bdd658ef010000a445ec1f2291fc04e13287542dbb2ee9e1886de8def92f10dd1df0f98c6765ba4366bc66ae77031edd01440000000020da283c6b906e496e90ac9c7aa5527b582bd54b042e6ebb26b4a3ba3c3d0200003dbe8a9bc19f6d4aed4ab42c74babcefb61c1316f348895f067970b8d75c23506266bc66ae77031ef3ba2d0000000020418de557ee6f030c1db99434ce1494b215611cc6e18c6edec435847b82000000a8a09f7524db35b073d863c7a81dc406f4312c0703b175a00acdbadeb8d037e78166bc66ae77031ed2081f000000002053926576075971998ab35b711b03891e86771e05949867770f64d665a9020000079514ca61a203458ac8dcc22580ba903303e45df6b05fe84408a1d75bc486609f66bc66ae77031e823805000000002058088ab91e2b706f63874c3e6e309fe75282b4a9273bb71070a2c0a1f4000000f043daf17dd34a48bf6edcc5f94c7b473e0e664ac7ad64e63a9d9971d7a87312bd66bc66ae77031e1a602b00000000205fb8bd7b9b668ee64585f3a2fb0181dd4e4cbe63951d835c3ba9b3265e0200007df37f22ecd4304f182e1a73175cabbcb5cfb8ae68fff4e1cfddb2f53e68d256dc66bc66ae77031edd87090000000020f1d03f4e9ddb20d8fede13cfa7473cc197e2f3cacb6cbd1fe04c8e5b65020000fd3e23dbc6f538c82b438f990ffcf7d4fc22723d05dc3ebf15ae78ca0c7f059dfa66bc66ae77031e604f6200000000200b1ae86b3c010fef763a9205102840ac2b53e11277ed71f0416f6184a1010000078df2ffc80c46e3a4b5f5dd680f85a1286ee3e14fb428ea15af8f64f7e060e31a67bc66ae77031e45a72c0000000020b353730e012a61dde214df09feb643d11267a6952d2af038e9b2674c500200009798e8e884bd72bdc1cfeb1155113e0240dbe1ee462efc0c0639f9236b2d9ac43867bc66ae77031e0eb31b0000000020cd3ec12b255a1ab4c5dd4dd285f1184e528ca475cc7ebbef010c56849b020000856b4ef803cd6b0de3aab51e008fab474a65f0a3bf718ac06742ec7610c8772d5767bc66ae77031efceafb0000000020322c45b9d252e7d1aabd4a030cc383fdd785253f2c962e14f59f5e5b14020000bb9a355c0c3f13825e20579f32baa3554ce222b895a8be1ecceebffe5f2626b97867bc66ae77031ee51d19010000002008e70c168dfbb88d6319d6ea549f6fd2224163409e6ba52f8aecde4ddd0200000e5b22cb2fdb354a865409df08fb41bc34ceaedd4c1cb6cd3d7fdab5532d278b9a67bc66ae77031e337f0e01000000203780456416e93d3aa892e214a84beeb5567da7a8592f9ce6def8bbc147030000e5802c62231e74b3f37385599e723bb01734be2fb72e9e68cac555884dbfd6b8bb67bc66ae77031e1e740700";
    bytes32 constant keyHash01 = hex"000002a965d6640f77679894051e77861e89031b715bb38a9971590776659253";
    uint32 keyTime01 = 1723623041;
    uint256 keyHeight01 = 1344020;
}
