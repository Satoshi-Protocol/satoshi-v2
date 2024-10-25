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
            from: holeskyContract,
            to: sepoliaContract,
        },

        {
            from: sepoliaContract,
            to: holeskyContract,
        },
    ],
}

export default config
