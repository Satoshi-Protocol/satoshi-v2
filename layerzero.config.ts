import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'DebtToken',
}

// const arbitrumSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.ARBITRUM_V2_TESTNET,
//     contractName: 'DebtToken',
// }

// const baseSepoliaContract: OmniPointHardhat = {
//     eid: EndpointId.BASE_V2_TESTNET,
//     contractName: 'DebtToken',
// }

const holeskyContract: OmniPointHardhat = {
    eid: EndpointId.HOLESKY_V2_TESTNET,
    contractName: 'DebtToken',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        // {
        //     contract: arbitrumSepoliaContract,
        // },
        {
            contract: sepoliaContract,
        },
        // {
        //     contract: baseSepoliaContract,
        // },
        {
            contract: holeskyContract,
        },
    ],
    connections: [
        {
            from: sepoliaContract,
            to: holeskyContract,
            config: {
                sendLibrary: '0xcc1ae8Cf5D3904Cef3360A9532B477529b177cCE',
            },
        },
        // {
        //     from: sepoliaContract,
        //     to: arbitrumSepoliaContract,
        // },
        {
            from: holeskyContract,
            to: sepoliaContract,
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
