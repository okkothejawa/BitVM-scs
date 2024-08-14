// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/EBTC.sol";
import "../../src/Storage.sol";
import "../utils/Util.sol";
import "../mockup/BridgeTestnet.sol";

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
    bytes32 constant N_OF_N_PUBKEY = 0xd0f30e3182fa18e4975996dbaaa5bfb7d9b15c6d5b57f9f7e5f5e046829d62a4;
    bytes32 constant OPERATOR_PUBKEY = 0x58f54b8ba6af3f25b9bafaaf881060eafb761c6579c22eab31161d29e387bcc0;
    bytes constant WITHDRAWER_PUBKEY = hex"02f80c9d1ef9ff640df2058c431c282299f48424480d34f1bade2274746fb4df8b";

    address owner = vm.addr(1);
    address withdrawer = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address depositor = vm.addr(3);
    address operator = vm.addr(4);
    address submitter = vm.addr(5);

    function buildStorage(StorageSetupInfo memory params) public returns (StorageSetupResult memory) {
        string memory json = vm.readFile("test/fixture/test-data.json");
        address withdrawer = abi.decode(vm.parseJson(json, ".pegOut.withdrawer"), (address));

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
        Bridge bridge = new BridgeTestnet(ebtc, _storage, N_OF_N_PUBKEY);
        ebtc.setBridge(address(bridge));
        vm.stopPrank();

        vm.startPrank(address(bridge));
        ebtc.mint(withdrawer, 100 ** ebtc.decimals());
        vm.stopPrank();

        vm.prank(withdrawer);
        ebtc.approve(address(bridge), type(uint256).max);

        return StorageSetupResult({
            _storage: address(_storage),
            bridge: address(bridge),
            ebtc: address(ebtc),
            owner: owner,
            withdrawer: withdrawer,
            depositor: depositor,
            operator: operator,
            submitter: submitter
        });
    }

    function getNormalSetupInfo() public view returns (StorageSetupInfo memory) {
        string memory json = vm.readFile("test/fixture/test-data.json");

        uint256 step = abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.step"), (uint256));
        uint256 height = abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.height"), (uint256));
        bytes32 blockHash = bytes32(abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.hash"), (bytes32)));
        uint32 timestamp = uint32(abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.timestamp"), (uint256)));
        uint32 bits = uint32(abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.bits"), (uint256)));
        uint32 epochTimestamp =
            uint32(abi.decode(vm.parseJson(json, ".pegIn.storage.constrcutor.epochTimestamp"), (uint256)));
        bytes memory headers = abi.decode(vm.parseJson(json, ".pegIn.storage.submit[0].headers"), (bytes));

        return StorageSetupInfo(step, height, blockHash, bits, timestamp, epochTimestamp, height + 1, headers);
    }

    function getPegInProofParamNormal() public view returns (ProofParam memory, ProofParam memory) {
        string memory json = vm.readFile("test/fixture/test-data.json");

        // Decode the individual fields
        bytes memory merkleProof = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.merkleProof"), (bytes));
        bytes memory parents = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.parents"), (bytes));
        bytes memory children = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.children"), (bytes));
        bytes memory rawTx = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.rawTx"), (bytes));
        uint256 index = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.index"), (uint256));
        uint256 blockHeight = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.blockHeight"), (uint256));
        bytes memory blockHeader = abi.decode(vm.parseJson(json, ".pegIn.verification.proof1.blockHeader"), (bytes));

        ProofParam memory proofParam1 = ProofParam({
            merkleProof: merkleProof,
            parents: parents,
            children: children,
            rawTx: rawTx,
            index: index,
            blockHeight: blockHeight,
            blockHeader: blockHeader
        });

        merkleProof = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.merkleProof"), (bytes));
        parents = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.parents"), (bytes));
        children = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.children"), (bytes));
        rawTx = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.rawTx"), (bytes));
        index = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.index"), (uint256));
        blockHeight = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.blockHeight"), (uint256));
        blockHeader = abi.decode(vm.parseJson(json, ".pegIn.verification.proof2.blockHeader"), (bytes));

        ProofParam memory proofParam2 = ProofParam({
            merkleProof: merkleProof,
            parents: parents,
            children: children,
            rawTx: rawTx,
            index: index,
            blockHeight: blockHeight,
            blockHeader: blockHeader
        });
        return (proofParam1, proofParam2);
    }

    function getPegOutSetupInfoNormal() internal view returns (StorageSetupInfo memory setupInfo) {
        string memory json = vm.readFile("test/fixture/test-data.json");

        uint256 step = abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.step"), (uint256));
        uint256 height = abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.height"), (uint256));
        bytes32 blockHash = bytes32(abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.hash"), (bytes32)));

        uint32 timestamp = uint32(abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.timestamp"), (uint256)));
        uint32 bits = uint32(abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.bits"), (uint256)));
        uint32 epochTimestamp =
            uint32(abi.decode(vm.parseJson(json, ".pegOut.storage.constrcutor.epochTimestamp"), (uint256)));
        bytes memory headers = abi.decode(vm.parseJson(json, ".pegOut.storage.submit[0].headers"), (bytes));

        return StorageSetupInfo(step, height, blockHash, bits, timestamp, epochTimestamp, height + 1, headers);
    }

    function getPegOutProofParamNormal() internal view returns (ProofParam memory proofParam) {
        string memory json = vm.readFile("test/fixture/test-data.json");

        // Decode the individual fields
        bytes memory merkleProof = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.merkleProof"), (bytes));
        bytes memory parents = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.parents"), (bytes));
        bytes memory children = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.children"), (bytes));
        bytes memory rawTx = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.rawTx"), (bytes));
        uint256 index = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.index"), (uint256));
        uint256 blockHeight = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.blockHeight"), (uint256));
        bytes memory blockHeader = abi.decode(vm.parseJson(json, ".pegOut.verification.proof.blockHeader"), (bytes));

        ProofParam memory proofParam = ProofParam({
            merkleProof: merkleProof,
            parents: parents,
            children: children,
            rawTx: rawTx,
            index: index,
            blockHeight: blockHeight,
            blockHeader: blockHeader
        });
        return proofParam;
    }

    uint256 step00 = DEFAULT_STEP;
    uint256 height00 = 1285280;
    uint32 bits00 = 503543726;
    uint32 time00 = 1721800455;
    uint32 epochTime00 = 1721766739;
    bytes32 constant initHash00 = hex"000002b9f8f94339e547060d0714c05736aad579ca52e57908f3712d9d62a236";
    bytes constant headers00 =
        hex"0000002036a2629d2d71f30879e552ca79d5aa3657c014070d0647e53943f9f8b9020000cafb1dc4fb99987c74f8bbfe225625dc9df2425760da97e5288846724949fc112597a066ae77031ecb151700000000203b5863ec4396b1dceca617beb7f14712b47df6fe4f4314d432fe2049990200002d544227c10b0e05337c2815f8c421f2a32f8b1814c8f30fabef50a2b5cb6bc64497a066ae77031e3ffd1c0000000020dbfaed9c70c09840f9f1b07d7c49e4a9c46a8a5e6173f789f7a91a73c800000004e690b09a5374d17775180340b2f5a85dd144ad11a84b088bd294bfd2b52e106297a066ae77031ed15d630000000020c144655a65e9acc65a70a3a637863dc37958aac54410d555983324318202000019b593b07802c050ce5486cf21637bf0f8a4f7672aa25821492473f3c2cdec208197a066ae77031e7aee0400000000206fd16f539e8b5c480d4db7f31f097ebde51ae9ce17caf1a8fd56532bf60100007f78869b9f3db80e4802befe1fa95e5161d63cfadfa3e56ac20442906124ba46a097a066ae77031e56cbc200000000207271ae24604a9c11aa5dd16ba65bbb8ffe12dba2a298a551986fdc8cd40200005f3ecbfc21ac972df03dc4fba53d7db00f206d04e6dc98dee48869d6f0b1dd18c097a066ae77031e4b820400000000206477117c904feec1a978be15048d45cb712996e3899dc3c799d1404c16000000ce978c67fd9cd8151f89a0ab425c50e0b9cabdb11416d01f44c3c6de5779c32cde97a066ae77031e4a0001000000002053f0ae5051b4ad552ca07df72645ec19f41c39a5ea4ad794ad24847727020000d559a248d892e7335a75d4eece34c61ac024ae540428e0cc088f7234ac5dd660fc97a066ae77031e1cbe4600000000204cb730edd2defcc893228ad2eb3e25c9a8a6a90a3789f4382392c31c35010000d4f409b06f9ba54fc525fc7fc6937238a9112583164a290949a37edde02cf1811b98a066ae77031e25a20e00000000206cdf416ba021732b6bbe9d10d5fa6e7d51f95ca2f51666e9daaddcfe47030000477a2470a5a33a2524cc12775b5a14ba1bc4497375396ecf0e634385a7db4be83a98a066ae77031e9bfa160000000020a8feb08a7024051d91816f132f2c31b7122dc0a77be4d2d63bc392162102000061985f22258737352e2fdfca66c8915f2ef0b4ffb41187e41646499e6fd63b645898a066ae77031e315c3f000000002016bddb9fd24f36b744d83d3e78d95373ab8a334b8ca64cf1282fe40d6e030000c758a3963df14e032c2ef31a657ce32ba9a39a7246e1a64130d387af8af8bb1e7798a066ae77031e231f520100000020626d982ac601144dabbd5b7941bb3b11b14748e25b4dd71aaf947add9d02000025dde734e4a906c4a5a96ce6644ebe45ed0ab0e3539a7c4168afd3743227e75b9998a066ae77031eebf3020000000020edb80c67c4edeeb61b3c817f45a05acb9942d024195ce372eab6932cd70100002a211c1b9a75c8f6874ca483538a012582b6d7db9e1a63d172d7797ff2d2b93ab798a066ae77031ee4a16c0000000020ea8450a2ddbd3d6216fe4ae0a334118234e2937c5fec089644f0132d4e000000c4f72d115071b30623c6c4baf95f50f26ccdb0364ac8722b5d0f14d39c6f3b75d698a066ae77031e92660a00000000204b5d9c2eebcc0b08c16a5921c91635db9e9ad5bdf4b9d18c1ee2736a3103000045d416bcbfd971585a7f0f8717f18830006093c5d40c7c9d524dc8e35f10c935f498a066ae77031ef7a4250000000020680322f000ae16072444c0343424322e53702ba6ac73ce1972ca5331fd000000ce14d730d459a3c5e3a7a3f861bb03363004055b0ebe714f87782db1a26aafc91399a066ae77031ecef24e00000000200f94b9274636ee09e1da31ddb6510588000e51da7a9075c87b9657d299000000ed32501244e456cec51b3e1ac24537d2b0011aa69f1f8bed0f9716332369578f3299a066ae77031efdc11000000000201f0cfe2e536bfbc7d0e528b24e457063bdd64e027adb1d8085e435e8ee0200007be28adff0190030f72e342a182a578e3f67e54e9b5f11996850efea6e3990875099a066ae77031e8ba21700000000203522295e50871186bc2a4f81cc91b7b32b6bb45de1053601df32c61cda020000e6c973ecb929543b45663b1ea9ff56c36e643ed5f4f011bd29c37b48d0fc241b6f99a066ae77031ea3c8720000000020ca0ff7b9f96206a8151a9260a0017b921a28501ff454bcb645e15ea66800000033355516495a530cd5b4d22effb3a223f9df52ce516d32fd3db9971cda4317ed8e99a066ae77031e2c98590100000020b92119d922823be235d8796c69a70dcce693aa0f51a426b1ec33a774200200003d558ad9484106896c64d226af10bff5a43c44fb3818e169853908bf36244338b099a066ae77031e2109df000000002058702319836adeb3b28b68a028a79930577c048977adb184e72fa9ff0e030000f5a5cf66cf80038cff122b9834daefe0bb1b41a0e021e6392367042f1e1f547ed199a066ae77031ef4f6330000000020fc3b86c54203f0e46c4bdcd9edc4f4321912a259d1fdd4aade9eb236650000003c9c7b610fc9166c84fb6048223d0a09a41c8e8c3ebe479c4c33407e31b3f777f099a066ae77031e8d52530000000020a51ea62908451cc02141e2fa48668348af572a8b54dcdbcd95ccef209702000034069dc3c29b0daeba1ab0f4ab76813b14707199b80817470e3ee8b79b0be5800f9aa066ae77031ead69260000000020661d90dc5b0860f1cfb2284d16caa55cb95a22ce79d1de466f938e3586000000d2a634f792b577a08afb499ab2810951b368b45924143b4a261431260ae8089f2e9aa066ae77031ea5131c0000000020dbf0114ce5bf5279d7af28c5cf426e956ee03c1135bac7b838bffe7ccd010000442a7ba5c43e330067da7a971b13c9efe865ddba232585a53b3d296ad6f3675f4c9aa066ae77031e81db1d0000000020d23daf2c25a937cb1a4cff5b018cd7331c012769679bdcd349937cd53602000081477c0028014562868b1619f753bae5c72a08bbb4e488651f34b06a6e62f6516a9aa066ae77031e3e4b03000000002015f633ae1503c0030a57947a7b94453ba737c9b8a06db97fcc6e2180c9010000617a79ea1c976605699a7426b8929c01aad8714a6c4e0a33621f8d93baa7f59f899aa066ae77031ee9bb4f0000000020ddb5fb3602f57084daf786e379308ce14561dcb7d685b3a1eeaa44ec69000000c0de0d516bd487ae845b5601b4bc6576f15256723567a78c0aa33b3e930c3422a89aa066ae77031e5b6d9b0000000020e3fa11fa18d4cff6756c2756684469ad7749410536c7fe9da5e48779e4010000ac553a025ee4a13a8d9a4c88f2ca62c98b87c38619e1842db4f7915d52afc24ac89aa066ae77031e024e8c00000000205e36a9bdedec8bb5eceb6a790964d2de761f35100967a4d3eb079e4cf002000031ff767a38a8990bf5cc532cc8d3c98ef2d7420f5e8b914bf4f3767402558864e79aa066ae77031e3ddd3b0000000020f8d1de60f20e9916934306cf7f984327ba9cc024cdeb2eecb72bc9db2b01000047866e021328525e2b8b803a8d3a55920ab69e5cb087f04479085bfc047025db069ba066ae77031ebc0c180000000020c8aaa981e82a6816c3b1a4927e52a6bb54c6d54d374fcf6e62498883430200002c581483c1138339968276b18c24b44f7e8de5949debcf95d0d1af8fd337f1a4249ba066ae77031e7b142b0000000020f46dede33206eb89545c265eafb95659fa43d0925543b65c09a79b2cc7010000f7256c4e955f799b185da11f94258de5e920ad71abd4912f581e080ee7bb6c00439ba066ae77031e1dd92100000000204fa35fbf16e3e48abd5309387232d2d3f44f3ffc5259d5501a77a16d0d0100004317fa0ded2de59532ee5675eb7de8f9b15228217d9d77842c580855ade57f00629ba066ae77031e3f8e1b0000000020e9dda8a8421c3f5998fd54d833f62fc9b67c6f02fdd92b79c098388041030000c8ef2b8b01e761e4d5d1bbfca2955e3ed7e082768f3cf9ee5742c03c0c76cd40809ba066ae77031e61b106000000002053b2b599f3502eb4f495797d74c6d467468f8cf9f9baca4b09b724d256000000d691e5d914e5107d1d3b304e0478471aa65e79502bcda374c6deafefbce555879e9ba066ae77031ed69d4700000000206306e352c7445bf9546bf33e1497f936ba97c1737dea7bb7ea12275aac010000141fd3403318a876de659e366b3a31ab081d7fc6867ca8624b77d782ba945791bd9ba066ae77031ef828170000000020865979c36f94c4043d54e426ec4df81c9eeadafc38dbcb15fce098b743020000c74de06cf134a40309d39507d0e1bcaed90ed0754aa63c400663388a93d72ef8dc9ba066ae77031e1cdd0700000000209fe89a37d819e0256f1966fa4e5b5fb1bfc567d0ca502dcdef703dada6000000290da1977356014f9895c0d0f737a4a88f747fa09d614f1198d507bd68c6f5defa9ba066ae77031ecdd91200000000205bc9c11b5e222eab6a8ca9f3b6614503877a9a34b5bb648eae03c8b75600000006985a1ee3681ca44df32e3b5f0e5cb6d9a890855867efddea4b86091183076b189ca066ae77031ece6526000000002041c53a89959d498bca8a03844a0c817ebbbfa60322b57139279e0e9798010000e09a4b91e71d24ed0f0921adbaabc02b444093e88506c802f3797653bdefcbff379ca066ae77031e66ef130000000020aca04b964a8e8f2d24f0d86c5099e61ea84103434f4f825d7b4eae7ca8000000c769f0653bcac6742dfff1ef30378b1b9c23faa31c50fbb83afd5b958536f8dd559ca066ae77031eef053700000000205105c75471b0920b40605f5492a98034bd6e5dd8665ca965d8039b3dbe0000006f0da3b8dc650bc29963422335f7943d6a9a0d291a22bb69381d87ab2e33a5f0749ca066ae77031e19a2cc00000000208ca8295615b14e3e6381b89fbbe6529bd995515607377ee8488035f4c500000079f874fb1ccda10c4accfbfceafad1e6cb03c1ac71c4a74cd5ce2209d7212726949ca066ae77031e8391170000000020ad20ab153f7d3e5ad5ce12b8f5ce93e5303935dc63485efe8c3def2dba00000066b7ea8dcfc689ffef2de0ce1b6876ba99882a4630bff187e2728483ba594638b39ca066ae77031e478f3f0000000020dfb0864e1fb75d87590ee926dd4ae1a47df42053253591fe95d48a97ae01000039cd6ac214cf981ec881c0aca866e6441d7c4e0fd0e2254c6bb8d505e5323b71d29ca066ae77031e7beb590000000020a1b246308959e668b1d97b1a7e5279190241feb521762bb30a714455d602000040a592e267ad5550e7cbdc8f9706ceb0bda650ca2546213eb6dea6740f4549a2f19ca066ae77031e20528d0000000020a92282208bc84d4bbdabc4d2f12c6adf53413ee103d7fc7531a6dcf0c90200009b3224c6fa5a642123902e8d8915f42d87f6e01a276136b2b1405a487ed736a7119da066ae77031e56fc8101";
    // first keyBlock(init height + step) hash
    bytes32 constant keyHash00 = hex"000002211692c33bd6d2e47ba7c02d12b7312c2f136f81911d0524708ab0fea8";
    uint32 keyTime00 = 1721800762;

    uint256 step01 = DEFAULT_STEP;
    uint256 height01 = 1303440;
    uint32 bits01 = 503543726;
    uint32 time01 = 1722363723;
    uint32 epochTime01 = 1722329458;
    bytes32 constant initHash01 = hex"000001cdf48d9f534300100b5b03aee7a9b9bd5159e96bb464cbefdb4db54f1a";
    bytes constant headers01 =
        hex"000000201a4fb54ddbefcb64b46be95951bdb9a9e7ae035b0b100043539f8df4cd010000ae680053802f3a19644b3f48f7a154d0f8494bf989b4c77bcca6987d787f4b0d6b2fa966ae77031e6a0c830000000020efd800517133b07ca53e9b19b6adc46bb26ec088d19dd887cad93038ca01000008d11da6b80727d8ad1693d27d9aa1dbdf48db09742e673d68a4212858cffd788b2fa966ae77031e11551900000000201810e72d66125aa94028b5d0875c5bafd69dca91f0a6f2c6c30dea2461010000458bbd950bc341820ccf22eb7cc96aa912418f926c7b491024fce93bb1e3e761a92fa966ae77031e72df8500000000203630322e762b815e6b771d3a786d1d093d20bec7df37dccf98e0f16ae0000000b43aae378123a6d59e34f9ec885df02c4a02ba91fbec53fa59b335b676a663e2c92fa966ae77031e107e2400000000209d02db992272626a0ef9520d3501d444fd00d92db0151b007480ca0ded020000b5241e8eba9b882a6a018308d6e2b5111ef4c7baf5ae6bbc9991dd810ab507b0e72fa966ae77031efde7080000000020229ad9c6e0e755fffe1f429d469a530499208a03dc38c311a86764c938020000c7882c202421a75de73054f8cb8856297c8fb379bd6e52ad37ff13a5ea09bdfe0630a966ae77031e00fe3800000000201f9f908f8e4f58b0992aadd80908789c0ad33614f5adca91be8bba9c64020000cabe4e99ca9aa167153f42689e734bc7cccc18c7533bcecc632a1b4148478dbc2430a966ae77031ea5dd180000000020b879643c79e8d4ff9ea204c1c6e71112c4ce6c2f0e82e822daac6723d5020000a8ed31e5513955624572910a98416d9bff245f0d2084d6b6549f57602b2a92954330a966ae77031ef3031a000000002027155eb91466badc288036ddb6e36de9434fa77bf76937a597f4baaed802000051c0c5c28ff90746d599153e41d54ca85b16948f7a0b3919068a4914dda1cfc46130a966ae77031ead3b500000000020a500ad536819c4f04abd7769debbfc9fdc16fd6d870016592e458f0bba000000ea907b697616ee0255c77f3868879f03f850455ef60a4dfa2e60437fa941d2868030a966ae77031e1f327b0000000020160c3439ad90cd702ff2c98210e7bac68990c53fcc9c1a84f0d7ffa37b020000a059505d44dddeb52a18a99a839c890863e89a59b67abbee84e124f543417b11a030a966ae77031e3908100000000020c336bf351a23dcaff3265f9b22ea26c97337f271da3bd46aaa051f21ec0200006b247001cfc63aea2b5361b9b03217c776f9c7ef3cd7fd9f47cfde0a85e5042fbe30a966ae77031ed9c424000000002068d31e30158248c88643f7098cb7e6267c28136e5abdbce589be1be3f1010000b9f7f000073595f008aaa0bb4ebe50ab1612bf73b3cdd26ee1d7c94372e44228dd30a966ae77031e9d3c1c0000000020589c7f34c4a08aed028222236a765e82b76743c0354f3b989a4dc0c8c702000027ccbda2f70255cb8477e90ce15c9d791f44d3b4d6493376e7d1fea3a51f6958fb30a966ae77031efbe51700000000200e926270e687d42ee3556cc392724b228829df93dc034907ea0dbbb720000000195b7485976fd2b7b5a830b8279ec704527eba401a12aef9785870a7b90edc171a31a966ae77031eec5f6a00000000206277db494f5df740473287607a9fef31278e8d8f1a897ba3f7d40d507603000049e1c969f527ee45a654290d7d8ecbc9aab878824b399aca68fee4f729df5e363931a966ae77031e6794e3000000002000df6f0835cfeea835fdfc95ef34087a6f2264c52b78c5ae950525e05b020000dee50c36b9244ec711268cf8cd69765b479565683ebd6215362b81988071fab85a31a966ae77031ee18f470000000020932a1fb8b8ffae23c4fb5a02be2df35c494af77dbb86480deb208bab21030000f4daf8afe698b52c48e075b9faeda63abeafcf7b7c23f991db68cee27210e1a17931a966ae77031ebee501000000002090e4b5fb73803ecad3fb2a997b2d8dabdd054782e42ea74974e7a2d7ba020000f500ece8e47e23afc6c3b2918d46f0d8dbad102f5d6b25a45f402f77aa9196009731a966ae77031e14270c00000000203eab760167ddcd77ef29f43074f9bd3ef5add10a47a62c9ecfb5580e3d0300008483dfdf267b8b2dab7961514ab3d42f3aa5f18a2a703f840bc92233b73521d7b531a966ae77031e408d1f00000000208415f586c5d6a7d386e2f23f22f0f2cfadbd90d1fa5b9de6101f4efc9500000037947e20f31e8c5160fc51265f1f15d83df22374b8285eaaedb3ba7122876391d431a966ae77031eda834700000000204e997ce9cba84b85a4e6b4d5b100c6b3127a9134f2a2d9ece4db4a87660000006db83b950f5541b01d3afb7b2c3df0faf87465dc56391e7846d44f5125678614f331a966ae77031e442d04000000002060a25773a309b22988e3a76fdf9fe0e076c9a174dcef7d3f43ffb2b0060000002c57a887a1a11761c4a72522806529f91ac508370c48ccf1edf329011ede8e9f1132a966ae77031ec4ff4b00000000204a95f73baff97675c20738cad0fe588ea9ac5de6a36ff251c8cc03796e0300004c20067d46e39c630765027cadf52980e8dfaad25244753f742460812a3dcc2f3032a966ae77031ef4b79800000000202cf2c16aa1cc70e8e2f1dca54bcf769881b810becba97fe3e184d25f810200001a63b3e0ad804284e988850b96a74afb053bba07abb5c2b1589dd92ee0f663bf5032a966ae77031eb18f0600000000202117f766c60d99c5709218f1d6fda3e7ba14d40a4e21cf3eeaf12af4e8000000b42f3678064766e281fd8f462e7b5f6522ba76c82f5ea5a3d9c6851bf43df0e16e32a966ae77031e355fa2000000002076c2088550eb273a25e5ad506601b1d0cca6ff6d4b09f7a904632aee21000000abe7dcc5b5f6117e0b9d993abb68677cd373b3dcf2841aa16e3c5191763db73d8e32a966ae77031e2fa2520000000020a8f6b2b6868136e25a70f4d769cf4767af300ddc419df161d24393bdf4000000aa712119556ccf994172e94b31f9398121215e770edd0aa4b8fbedcabe32fdebad32a966ae77031e49e083000000002082eb4d8cd756431c169d4f9ddbedcc0c9e9c81743b7c8123f688473c9402000047d21d4539ca9e5bd3e0eaa6bb7fb274cee50fe99fdf9a1b515c7fee8b482fa8cd32a966ae77031e6ef5090000000020904ecb656f2f0d342e89108ccb3eaae71c3537b9eb9ca39da5902b325e0100009163d677f8e57898ed68a1a3e667dbccb4970f6cc57c81cf722bfd0131216ebceb32a966ae77031eab10dd00000000202529459b096c2b8b91324de21a0329da5f312348a0b42a0f7a31634fdd000000048d3715f6c955a4d92853073b6a3d23368b113781bb0100d9961aa0a23216830c33a966ae77031ecb1f0e0000000020f8f7e869b2e1c174bb610e4ccd1e0bc11e01e90c0bc47ade027804309e010000039626721755ffbb5ab0fa4d17c249ad7f7ac359e8a9aa6e0cc1e9dd137b4ba32a33a966ae77031eb3530c00000000204cc3f6ca5617a022c55434090ece549f81f96aca7f8a312f5e83c36f45020000d1021a5ccad4b515ba5600f3972ea97bb1af4421ce6c2d88e21a6a3208e329904833a966ae77031e443a360000000020c05f77f2444ff9ab40e2b431a993a678adbc19b97cc0f50efa07337b10020000cf45903364b2a3f660ced32ddc89ea11adc694fdbbc42516a9e3bae89c21e4996733a966ae77031eb885780000000020559506a73b383a2884bfd483e407ef9626dd6f708361b5e8c1f9c12c8c0200002b6ff76821992a32aef80439adb4e995d212d466cc4b272559e2fdd6d1f52e4d8833a966ae77031eceea8c00000000202a2407790ff997d27511729a7a709275b42d63fa50dec396036f7463f00000002dd26aecc999d25b3c5d9639a263b97b0b9dc940ffbf185cd15e835560ffd56ea833a966ae77031e0b6c3800000000207fc347b620df0da6789388827b2c90fde42bc48b7a192c59910c56dd5a030000f3f9cb075365d65dea15c695cf7339a065419d61aa9e16379a7b6b9a4102e082c733a966ae77031eb4a92400000000203faadd829b3599f0d7b9726eead3ad7d5f51172849b0af8e4311a0685003000086a0338b9a5ebb5cd31ccaabe29d642a0c38602f87acfdca1e400a9b8f2b2730e533a966ae77031e4b6609000000002048df539c875611e8fc7d5bc6e8de5a35d477aa1150df3a2ba6b4b066a600000059f90fddd3708c88d9138122002b9f04a7483d16e56212819f6aef59da4839f50434a966ae77031e8a683d00000000201aab6acb92e01ca0cc86bdc2ebfe7d4cecda2e2abc2e93ca427c10f06300000059c14ccb917182950b8c953acc93ce89b5520323a75eb174a5b3199e454075922334a966ae77031ea8a35200";
    bytes32 constant keyHash01 = hex"00000095fc4e1f10e69d5bfad190bdadcff2f0223ff2e286d3a7d6c586f51584";
    uint32 keyTime01 = 1722364341;
    uint256 keyHeight01 = 1303460;
}
