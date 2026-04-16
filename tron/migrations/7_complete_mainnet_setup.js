/**
 * Migration 7 – Complete Mainnet Setup
 *
 * Picks up where migration 1 left off after DebtToken proxy deployment.
 * Deploys: CommunityIssuance, RewardManager, VaultManager, SatoshiPeriphery,
 *          SwapRouter, HintHelpers, MultiTroveGetter, TroveHelper, TroveManagerGetter
 * Then:    diamondCut init, owner-only config, write mainnet.deploysetup.json
 */
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');

const ZERO_TRON = '410000000000000000000000000000000000000000';

// ── Already-deployed contract addresses (mainnet) ──────────────────────────
const DEPLOYED = {
    sortedTrovesBeacon: 'TWPeEWj63o55hej4Dj919Ayq7B2SHXFgwx',
    troveManagerBeacon: 'TPqgxoWHL7EWqcYnvd4H5sqoYt3SfN6vQw',
    initializer: 'TNQgvNF5NHZcasFgtzr1gz6CC6faggpDpQ',
    satoshiXApp: 'TCtcuDNLwMEVokEj3Hg8ZoQaN8vcPFvk18',
    coreFacet: 'TQ1CL7JRwdckJ1qfUD6ErVjWmz6ksFJqko',
    borrowerOperationsFacet: 'TPh2hirC5RXKjrFdG7UUC7EtgcfayTMkj6',
    factoryFacet: 'THfXeYwUBxBUstwo8YNpk161xbJq19oUt7',
    liquidationFacet: 'TB41729DxEdLbXo6eKyY4V5wytmpkPRVgG',
    priceFeedAggregatorFacet: 'TRFFj9vAdD1MGxxH314Dek7K5kdoZrgNWB',
    stabilityPoolFacet: 'TWPfdNhqBCoGxUvS1ZZkUfnsWFFeTW5wJf',
    nexusYieldManagerFacet: 'TNsyWpp2FU7u1tq3bY4xbotoJZ7d1kmbJL',
    oshiToken: 'TFP1F8TuRpXtkRkoGdWo8XMfYhPu9J93dU',
    gasPool: 'TEzyc172QZiveG1RFqLt3ctx1EmkZmVBhm',
    debtToken: 'TDuYuotF7qnMr39UVqhGeAB855eoKboqTB',
    communityIssuanceImpl: 'TRB2TPX7wyhDuHoy3NttncqD2uMxKkiffP',
    communityIssuance: 'TUCxhx33L3WXUvWA2d3njnuBJmmBEyTEeP',
    rewardManagerImpl: 'TBekuFPu5jiJyi466Cw8vGas3VJyPDHTtr',
};

// ── Artifacts ──────────────────────────────────────────────────────────────
const SatoshiXApp = artifacts.require('SatoshiXApp');
const CoreFacet = artifacts.require('CoreFacet');
const StabilityPoolFacet = artifacts.require('StabilityPoolFacet');
const Initializer = artifacts.require('Initializer');
const ERC1967Proxy = artifacts.require('ERC1967Proxy');
const DebtTokenWithLz = artifacts.require('DebtTokenWithLz');
const CommunityIssuance = artifacts.require('CommunityIssuance');
const RewardManager = artifacts.require('RewardManager');
const VaultManager = artifacts.require('VaultManager');
const SatoshiPeriphery = artifacts.require('SatoshiPeriphery');
const SwapRouter = artifacts.require('SwapRouter');
const MultiCollateralHintHelpers = artifacts.require('MultiCollateralHintHelpers');
const MultiTroveGetter = artifacts.require('MultiTroveGetter');
const TroveHelper = artifacts.require('TroveHelper');
const TroveManagerGetter = artifacts.require('TroveManagerGetter');

// ── Address helpers ────────────────────────────────────────────────────────
const toTronHexAddress = (v) => addressUtils.toTronHexAddress(v, tronWeb);
const toTronBase58Address = (v) => addressUtils.toTronBase58Address(v, tronWeb);
const tryToTronHexAddress = (v) => addressUtils.tryToTronHexAddress(v, tronWeb);
const toEvmAddress = (v) => addressUtils.toEvmAddress(v, tronWeb);
const normalizeOutputAddresses = (v) => addressUtils.normalizeOutputAddresses(v, tronWeb);

async function deployProxy(contractArtifact, implAddress, initArgs) {
    const proxy = await ERC1967Proxy.new(implAddress, '0x');
    const proxied = await contractArtifact.at(proxy.address);
    await proxied.initialize(...initArgs);
    return proxied;
}

// ── Migration ──────────────────────────────────────────────────────────────
module.exports = function (deployer, network, fromOrAccounts) {
    return deployer.then(async () => {
        if (network !== 'mainnet') {
            console.log(`[tron] Script 7 is mainnet-only. Skipping for network "${network}".`);
            return;
        }

        const apiKey = process.env.TRON_PRO_API_KEY || '';
        console.log('[tron] API key loaded:', !!apiKey);
        if (apiKey) {
            const h = { 'TRON-PRO-API-KEY': apiKey };
            // Set headers directly on the axios instances to avoid replacing
            // the providers (tronbox monkey-patches .request on them).
            for (const node of [tronWeb.fullNode, tronWeb.solidityNode, tronWeb.eventServer]) {
                if (node && node.instance) {
                    Object.assign(node.instance.defaults.headers, h);
                }
                if (node) node.headers = h;
            }
        }

        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}"`);
        }
        const setupCfg = networkCfg.deploySetup || {};

        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);

        const owner = tryToTronHexAddress(setupCfg.owner) || deployerAddress;
        const guardian = tryToTronHexAddress(setupCfg.guardian) || owner;
        const feeReceiver = tryToTronHexAddress(setupCfg.feeReceiver) || owner;
        const weth = tryToTronHexAddress(setupCfg.wethAddress) || owner;

        const minNetDebt = setupCfg.minNetDebt || '10000000000000000000';
        const debtGasCompensation = setupCfg.debtGasCompensation || '2000000000000000000';
        const spClaimStartTime = setupCfg.spClaimStartTime || '4294967295';
        const spAllocation = setupCfg.spAllocation || '0';
        const spRewardRate = setupCfg.spRewardRate || '0';

        console.log(`[tron] === Complete Mainnet Setup ===`);
        console.log(`[tron] deployer = ${toTronBase58Address(deployerAddress)}`);
        console.log(`[tron] owner    = ${toTronBase58Address(owner)}`);

        // ── Reference already-deployed contracts ───────────────────────────
        const satoshiXApp = await SatoshiXApp.at(DEPLOYED.satoshiXApp);
        const initializer = await Initializer.at(DEPLOYED.initializer);
        const oshiTokenAddress = toTronHexAddress(DEPLOYED.oshiToken);
        const gasPoolAddress = toTronHexAddress(DEPLOYED.gasPool);
        const debtTokenAddress = toTronHexAddress(DEPLOYED.debtToken);
        const sortedTrovesBeaconHex = toTronHexAddress(DEPLOYED.sortedTrovesBeacon);
        const troveManagerBeaconHex = toTronHexAddress(DEPLOYED.troveManagerBeacon);
        const communityIssuance = await CommunityIssuance.at(DEPLOYED.communityIssuance);

        // ── 2. Deploy RewardManager (impl + proxy) ────────────────────────
        const rewardManager = await deployProxy(RewardManager, DEPLOYED.rewardManagerImpl, [
            owner,
            satoshiXApp.address,
            weth,
            debtTokenAddress,
            oshiTokenAddress,
        ]);
        console.log('[tron] deployed RewardManager proxy:', toTronBase58Address(rewardManager.address));

        // ── 3. Deploy VaultManager (impl + proxy) ─────────────────────────
        const vaultManagerImpl = await VaultManager.new();
        console.log('[tron] deployed VaultManager impl:', toTronBase58Address(vaultManagerImpl.address));
        const vaultManager = await deployProxy(VaultManager, vaultManagerImpl.address, [
            debtTokenAddress,
            satoshiXApp.address,
            owner,
        ]);
        console.log('[tron] deployed VaultManager proxy:', toTronBase58Address(vaultManager.address));

        // ── 4. Deploy SatoshiPeriphery (impl + proxy) ─────────────────────
        const peripheryImpl = await SatoshiPeriphery.new();
        console.log('[tron] deployed SatoshiPeriphery impl:', toTronBase58Address(peripheryImpl.address));
        const satoshiPeriphery = await deployProxy(SatoshiPeriphery, peripheryImpl.address, [
            debtTokenAddress,
            satoshiXApp.address,
            owner,
        ]);
        console.log('[tron] deployed SatoshiPeriphery proxy:', toTronBase58Address(satoshiPeriphery.address));

        // ── 5. Deploy SwapRouter (impl + proxy) ───────────────────────────
        const swapRouterImpl = await SwapRouter.new();
        console.log('[tron] deployed SwapRouter impl:', toTronBase58Address(swapRouterImpl.address));
        const swapRouter = await deployProxy(SwapRouter, swapRouterImpl.address, [
            debtTokenAddress,
            satoshiXApp.address,
            owner,
        ]);
        console.log('[tron] deployed SwapRouter proxy:', toTronBase58Address(swapRouter.address));

        // ── 6. Deploy helper / getter contracts ───────────────────────────
        const hintHelpers = await MultiCollateralHintHelpers.new(satoshiXApp.address);
        console.log('[tron] deployed MultiCollateralHintHelpers:', toTronBase58Address(hintHelpers.address));

        const multiTroveGetter = await MultiTroveGetter.new();
        console.log('[tron] deployed MultiTroveGetter:', toTronBase58Address(multiTroveGetter.address));

        const troveHelper = await TroveHelper.new();
        console.log('[tron] deployed TroveHelper:', toTronBase58Address(troveHelper.address));

        const troveManagerGetter = await TroveManagerGetter.new(satoshiXApp.address);
        console.log('[tron] deployed TroveManagerGetter:', toTronBase58Address(troveManagerGetter.address));

        // ── 7. diamondCut init ────────────────────────────────────────────
        const initSelector = tronWeb.sha3('init(bytes)').slice(0, 10);
        const initFacetCut = [[initializer.address, 0, [initSelector]]];
        const rawInitData = ethers.utils.defaultAbiCoder.encode(
            [
                'address',
                'address',
                'address',
                'address',
                'address',
                'address',
                'address',
                'address',
                'address',
                'uint256',
                'uint256',
            ],
            [
                toEvmAddress(rewardManager.address),
                toEvmAddress(debtTokenAddress),
                toEvmAddress(communityIssuance.address),
                toEvmAddress(sortedTrovesBeaconHex),
                toEvmAddress(troveManagerBeaconHex),
                toEvmAddress(gasPoolAddress),
                toEvmAddress(owner),
                toEvmAddress(guardian),
                toEvmAddress(feeReceiver),
                minNetDebt,
                debtGasCompensation,
            ]
        );
        const initCallData = new ethers.utils.Interface(['function init(bytes data)']).encodeFunctionData('init', [
            rawInitData,
        ]);
        await satoshiXApp.diamondCut(initFacetCut, initializer.address, initCallData);
        console.log('[tron] diamondCut init done');

        // ── 8. Owner-only configuration ───────────────────────────────────
        const canRunOwnerConfig = owner.toLowerCase() === deployerAddress.toLowerCase();
        if (canRunOwnerConfig) {
            const debtToken = await DebtTokenWithLz.at(DEPLOYED.debtToken);
            await debtToken.rely(satoshiXApp.address);
            console.log('[tron] debtToken.rely done');

            const coreAsDiamond = await CoreFacet.at(satoshiXApp.address);
            await coreAsDiamond.setRewardManager(rewardManager.address);
            console.log('[tron] setRewardManager done');

            await communityIssuance.setAllocated([satoshiXApp.address], [spAllocation]);
            console.log('[tron] setAllocated done');

            const spAsDiamond = await StabilityPoolFacet.at(satoshiXApp.address);
            await spAsDiamond.setClaimStartTime(spClaimStartTime);
            console.log('[tron] setClaimStartTime done');

            await spAsDiamond.setSPRewardRate(spRewardRate);
            console.log('[tron] setSPRewardRate done');
        } else {
            console.warn(
                '[tron] owner != deployer — skipped: rely, setRewardManager, setAllocated, setClaimStartTime, setSPRewardRate'
            );
        }

        // ── 9. Write deployment output ────────────────────────────────────
        const deployment = normalizeOutputAddresses({
            network,
            deployer: deployerAddress,
            owner,
            guardian,
            feeReceiver,
            lzEndpoint: setupCfg.lzEndpoint || '',
            satoshiXApp: satoshiXApp.address,
            borrowerOperationsFacet: DEPLOYED.borrowerOperationsFacet,
            coreFacet: DEPLOYED.coreFacet,
            factoryFacet: DEPLOYED.factoryFacet,
            liquidationFacet: DEPLOYED.liquidationFacet,
            priceFeedAggregatorFacet: DEPLOYED.priceFeedAggregatorFacet,
            stabilityPoolFacet: DEPLOYED.stabilityPoolFacet,
            nexusYieldManagerFacet: DEPLOYED.nexusYieldManagerFacet,
            initializer: initializer.address,
            satoshiPeriphery: satoshiPeriphery.address,
            swapRouter: swapRouter.address,
            gasPool: gasPoolAddress,
            debtToken: debtTokenAddress,
            communityIssuance: communityIssuance.address,
            oshiToken: oshiTokenAddress,
            sortedTrovesBeacon: sortedTrovesBeaconHex,
            troveManagerBeacon: troveManagerBeaconHex,
            rewardManager: rewardManager.address,
            vaultManager: vaultManager.address,
            hintHelpers: hintHelpers.address,
            multiTroveGetter: multiTroveGetter.address,
            troveHelper: troveHelper.address,
            troveManagerGetter: troveManagerGetter.address,
        });

        const outputDir = path.join(__dirname, '..', 'deployments');
        fs.mkdirSync(outputDir, { recursive: true });
        const outputPath = path.join(outputDir, `${network}.deploysetup.json`);
        fs.writeFileSync(outputPath, `${JSON.stringify(deployment, null, 2)}\n`, 'utf8');
        console.log(`[tron] complete setup output written: ${outputPath}`);
    });
};
