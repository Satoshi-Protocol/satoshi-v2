import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const bevmContract: OmniPointHardhat = {
    eid: EndpointId.BEVM_V2_MAINNET,
    contractName: 'DebtTokenWithLz',
    address: '0x2031c8848775a5EFB7cfF2A4EdBE3F04c50A1478',
}

const bobContract: OmniPointHardhat = {
    eid: EndpointId.BOB_V2_MAINNET,
    contractName: 'DebtTokenWithLz',
    address: '0xecf21b335B41f9d5A89f6186A99c19a3c467871f',
}

const bitlayerContract: OmniPointHardhat = {
    eid: EndpointId.BITLAYER_V2_MAINNET,
    contractName: 'DebtTokenWithLz',
    address: '0xba50dDac6B2F5482cA064EFAc621E0C7c0f6A783',
}

const bevmConfig = {
    sendLibrary: '0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043',
    receiveLibraryConfig: { receiveLibrary: '0x2367325334447C5E1E0f1b3a6fB947b262F58312', gracePeriod: 0n },
    sendConfig: {
        executorConfig: { maxMessageSize: 10000, executor: '0x4208D6E27538189bB48E603D6123A94b8Abe0A0b' },
        ulnConfig: {
            confirmations: 10n,
            requiredDVNs: ['0x9c061c9a4782294eef65ef28cb88233a987f4bdd'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
    receiveConfig: {
        ulnConfig: {
            confirmations: 5n,
            requiredDVNs: ['0x9c061c9a4782294eef65ef28cb88233a987f4bdd'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
}

const bobConfig = {
    sendLibrary: '0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7',
    receiveLibraryConfig: { receiveLibrary: '0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043', gracePeriod: 0n },
    sendConfig: {
        executorConfig: { maxMessageSize: 10000, executor: '0xc097ab8CD7b053326DFe9fB3E3a31a0CCe3B526f' },
        ulnConfig: {
            confirmations: 10n,
            requiredDVNs: ['0x6788f52439aca6bff597d3eec2dc9a44b8fee842'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
    receiveConfig: {
        ulnConfig: {
            confirmations: 5n,
            requiredDVNs: ['0x6788f52439aca6bff597d3eec2dc9a44b8fee842'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
}

const bitlayerConfig = {
    sendLibrary: '0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7',
    receiveLibraryConfig: { receiveLibrary: '0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043', gracePeriod: 0n },
    sendConfig: {
        executorConfig: { maxMessageSize: 10000, executor: '0xcCE466a522984415bC91338c232d98869193D46e' },
        ulnConfig: {
            confirmations: 10n,
            requiredDVNs: ['0x6788f52439aca6bff597d3eec2dc9a44b8fee842'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
    receiveConfig: {
        ulnConfig: {
            confirmations: 5n,
            requiredDVNs: ['0x6788f52439aca6bff597d3eec2dc9a44b8fee842'],
            optionalDVNs: [],
            optionalDVNThreshold: 0,
        },
    },
}


const config: OAppOmniGraphHardhat = {
    contracts: [
        { contract: bevmContract },
        { contract: bobContract },
        { contract: bitlayerContract },
    ],
    connections: permutationConnections([
        { contract: bevmContract, config: bevmConfig },
        { contract: bobContract, config: bobConfig },
        { contract: bitlayerContract, config: bitlayerConfig },
    ]),
}


function permutationConnections(chains: {
    contract: OmniPointHardhat;
    config: any;
  }[]) {
    const connections: any = [];
    for (let i = 0; i < chains.length; i++) {
      for (let j = 0; j < chains.length; j++) {
        if (i !== j) {
          connections.push({
            from: chains[i].contract,
            to: chains[j].contract,
            config: chains[i].config,
          });
        }
      }
    }
    return connections;
  }

  
export default config
