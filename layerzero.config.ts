import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'DebtToken',
}

const arbitrumSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_TESTNET,
    contractName: 'DebtToken',
}

const baseSepoliaContract: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_TESTNET,
    contractName: 'DebtToken',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: arbitrumSepoliaContract,
        },
        {
            contract: sepoliaContract,
        },
        {
            contract: baseSepoliaContract,
        },
    ],
    connections: [
        {
            from: arbitrumSepoliaContract,
            to: sepoliaContract,
        },
        {
            from: arbitrumSepoliaContract,
            to: baseSepoliaContract,
        },
        {
            from: sepoliaContract,
            to: arbitrumSepoliaContract,
        },
        {
            from: sepoliaContract,
            to: baseSepoliaContract,
        },
        {
            from: baseSepoliaContract,
            to: sepoliaContract,
        },
        {
            from: baseSepoliaContract,
            to: arbitrumSepoliaContract,
        },
    ],
}

export default config
