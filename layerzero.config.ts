import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// const sepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.SEPOLIA_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x45186cf2F66f43cf0a777a753b4ABBcD812204E6',
// }

// export const holeskyContract: OmniPointHardhat = {
//     eid: EndpointId.HOLESKY_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x4716c7b4fb7d8eD75B4D8904209b213308de837f',
// }

export const arbitrumSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ARBSEP_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0x85576DEa799eC912AAf05566922EaC75fC97Bd79',
}

// export const optimismSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.OPTSEP_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x512F0966853cE4f7F64094E42426a0deB16085Fb',
// }

// const baseSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.BASE_V2_TESTNET,
//     contractName: 'DebtToken',
// }

export const base_sepoliaContract = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0xBeD1808E6Dec5aDee59B1671Da8CFa81a9A1F2D3',
}
// export const coredao_testnetContract = {
//     eid: EndpointId.COREDAO_V2_TESTNET,
//     contractName: 'DebtToken',
// }

// send & received library related to the DVN on lz
// link: https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/default-config#setting-send-and-receive-libraries

const config: OAppOmniGraphHardhat = {
    contracts: [
        { contract: base_sepoliaContract },
        { contract: arbitrumSepoliaContract },
        // {
        //     contract: arbitrumSepoliaContract,
        // },
        // {
        //     contract: holeskyContract,
        // },
        // {
        //     contract: optimismSepoliaContract,
        // },
        // {
        //     contract: baseSepoliaContract,
        // },
        // {
        //     contract: holeskyContract,
        // },
    ],
    // TODO: generate by script
    connections: [
        {
            from: base_sepoliaContract,
            to: arbitrumSepoliaContract,
            config: {
                sendLibrary: '0xC1868e054425D378095A003EcbA3823a5D0135C9',
                receiveLibraryConfig: { receiveLibrary: '0x12523de19dc41c91F7d2093E0CFbB76b17012C8d', gracePeriod: 0n },
                sendConfig: {
                    executorConfig: { maxMessageSize: 10000, executor: '0x8A3D588D9f6AC041476b094f97FF94ec30169d3D' },
                    ulnConfig: {
                        confirmations: 2n,
                        requiredDVNs: ['0xe1a12515f9ab2764b887bf60b923ca494ebbb2d6'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 1n,
                        requiredDVNs: ['0xe1a12515f9ab2764b887bf60b923ca494ebbb2d6'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
            },
        },
        {
            from: arbitrumSepoliaContract,
            to: base_sepoliaContract,
            config: {
                sendLibrary: '0x4f7cd4DA19ABB31b0eC98b9066B9e857B1bf9C0E',
                receiveLibraryConfig: { receiveLibrary: '0x75Db67CDab2824970131D5aa9CECfC9F69c69636', gracePeriod: 0n },
                sendConfig: {
                    executorConfig: { maxMessageSize: 10000, executor: '0x5Df3a1cEbBD9c8BA7F8dF51Fd632A9aef8308897' },
                    ulnConfig: {
                        confirmations: 2n,
                        requiredDVNs: ['0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
                receiveConfig: {
                    ulnConfig: {
                        confirmations: 1n,
                        requiredDVNs: ['0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8'],
                        optionalDVNs: [],
                        optionalDVNThreshold: 0,
                    },
                },
            },
        },
        
        // {
        //     from: coredao_testnetContract,
        //     to: base_sepoliaContract,
        //     config: {
        //         sendLibrary: '0xc8361Fac616435eB86B9F6e2faaff38F38B0d68C',
        //         receiveLibraryConfig: { receiveLibrary: '0xD1bbdB62826eDdE4934Ff3A4920eB053ac9D5569', gracePeriod: 0n },
        //         sendConfig: {
        //             executorConfig: { maxMessageSize: 10000, executor: '0x3Bdb89Df44e50748fAed8cf851eB25bf95f37d19' },
        //             ulnConfig: {
        //                 confirmations: 1n,
        //                 requiredDVNs: ['0xAe9BBF877BF1BD41EdD5dfc3473D263171cF3B9e'],
        //                 optionalDVNs: [],
        //                 optionalDVNThreshold: 0,
        //             },
        //         },
        //         receiveConfig: {
        //             ulnConfig: {
        //                 confirmations: 1n,
        //                 requiredDVNs: ['0xAe9BBF877BF1BD41EdD5dfc3473D263171cF3B9e'],
        //                 optionalDVNs: [],
        //                 optionalDVNThreshold: 0,
        //             },
        //         },
        //     },
        // },

        // {
        //     from: arbitrumSepoliaContract,
        //     to: optimismSepoliaContract,
        // },
        // {
        //     from: holeskyContract,
        //     to: arbitrumSepoliaContract,
        // },
        // {
        //     from: holeskyContract,
        //     to: optimismSepoliaContract,
        // },
        // {
        //     from: optimismSepoliaContract,
        //     to: arbitrumSepoliaContract,
        // },
        // {
        //     from: optimismSepoliaContract,
        //     to: holeskyContract,
        // },
    ],
}

export default config
