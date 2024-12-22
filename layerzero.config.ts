import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// const sepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.SEPOLIA_V2_TESTNET,
//     contractName: 'DebtToken',
//     address: '0x45186cf2F66f43cf0a777a753b4ABBcD812204E6',
// }

export const holeskyContract: OmniPointHardhat = {
    eid: EndpointId.HOLESKY_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0x4716c7b4fb7d8eD75B4D8904209b213308de837f',
}


export const arbitrumSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0xD07a57DF618562A99DDf34c3Fcdadb1b143381f6',
}

export const optimismSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.OPTSEP_V2_TESTNET,
    contractName: 'DebtToken',
    address: '0x512F0966853cE4f7F64094E42426a0deB16085Fb',
}

// const baseSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.BASE_V2_TESTNET,
//     contractName: 'DebtToken',
// }


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
        {
            contract: optimismSepoliaContract,
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
        },
        {
            from: arbitrumSepoliaContract,
            to: optimismSepoliaContract,
        },
        {
            from: holeskyContract,
            to: arbitrumSepoliaContract,
        },
        {
            from: holeskyContract,
            to: optimismSepoliaContract,
        },
        {
            from: optimismSepoliaContract,
            to: arbitrumSepoliaContract,
        },
        {
            from: optimismSepoliaContract,
            to: holeskyContract,
        },
    ],
}

export default config
