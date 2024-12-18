import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// const sepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.SEPOLIA_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x45186cf2F66f43cf0a777a753b4ABBcD812204E6',
// }

export const arbitrumSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0x3ceE176f0f36B649CDdcD6d065ba4098B7726509',
}

// const optimismSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.OPTSEP_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x45186cf2F66f43cf0a777a753b4ABBcD812204E6',
// }

// const baseSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.BASE_V2_TESTNET,
//     contractName: 'DebtToken',
// }

export const holeskyContract: OmniPointHardhat = {
    eid: EndpointId.HOLESKY_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0x64F6Ca5F68D940384764c68274FD682E4e1677B5',
}


// send & received library related to the DVN on lz
// link: https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/default-config#setting-send-and-receive-libraries

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: arbitrumSepoliaContract,
        },
        {
            contract: holeskyContract,
        },
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
            from: arbitrumSepoliaContract,
            to: holeskyContract,
            // config: {
            //     sendLibrary: '0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE',
            // },
        },
        // {
        //     from: sepoliaContract,
        //     to: arbitrumSepoliaContract,
        // },
        {
            from: holeskyContract,
            to: arbitrumSepoliaContract,
        },
        // {
        //     from: holeskyContract,
        //     to: arbitrumSepoliaContract,
        // },
        // {
        //     from: arbitrumSepoliaContract,
        //     to: sepoliaContract,
        // },

        // {
        //     from: arbitrumSepoliaContract,
        //     to: holeskyContract,
        // },
    ],
}

export default config
