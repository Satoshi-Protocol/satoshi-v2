const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');

const ZERO_EVM = '0x0000000000000000000000000000000000000000';
const ZERO_TRON = '410000000000000000000000000000000000000000';

const SatoshiXApp = artifacts.require('SatoshiXApp');
const BorrowerOperationsFacet = artifacts.require('BorrowerOperationsFacet');
const CoreFacet = artifacts.require('CoreFacet');
const FactoryFacet = artifacts.require('FactoryFacet');
const LiquidationFacet = artifacts.require('LiquidationFacet');
const NexusYieldManagerFacet = artifacts.require('NexusYieldManagerFacet');
const PriceFeedAggregatorFacet = artifacts.require('PriceFeedAggregatorFacet');
const StabilityPoolFacet = artifacts.require('StabilityPoolFacet');
const Initializer = artifacts.require('Initializer');

const DebtToken = artifacts.require('DebtToken');
const DebtTokenWithLz = artifacts.require('DebtTokenWithLz');
const GasPool = artifacts.require('GasPool');
const SortedTroves = artifacts.require('SortedTroves');
const TroveManager = artifacts.require('TroveManager');
const ERC1967Proxy = artifacts.require('ERC1967Proxy');
const UpgradeableBeacon = artifacts.require('UpgradeableBeacon');

const OSHIToken = artifacts.require('OSHIToken');
const CommunityIssuance = artifacts.require('CommunityIssuance');
const RewardManager = artifacts.require('RewardManager');
const VaultManager = artifacts.require('VaultManager');
const SatoshiPeriphery = artifacts.require('SatoshiPeriphery');
const SwapRouter = artifacts.require('SwapRouter');
const MultiCollateralHintHelpers = artifacts.require('MultiCollateralHintHelpers');
const MultiTroveGetter = artifacts.require('MultiTroveGetter');
const TroveHelper = artifacts.require('TroveHelper');
const TroveManagerGetter = artifacts.require('TroveManagerGetter');
const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const toTronBase58Address = (value) => addressUtils.toTronBase58Address(value, tronWeb);
const tryToTronHexAddress = (value) => addressUtils.tryToTronHexAddress(value, tronWeb);
const toEvmAddress = (value) => addressUtils.toEvmAddress(value, tronWeb);
const normalizeOutputAddresses = (value) => addressUtils.normalizeOutputAddresses(value, tronWeb);

function isZeroAddress(value) {
    if (!value) return true;
    const v = String(value).toLowerCase();
    return v === ZERO_EVM.toLowerCase() || v === ZERO_TRON.toLowerCase();
}

function fromSun(value) {
    return Number(value || 0) / 1_000_000;
}

async function preflightResources(deployerAddress, preflightCfg) {
    if (preflightCfg && preflightCfg.enabled === false) return;

    const account = await tronWeb.trx.getAccount(deployerAddress);
    const resources = await tronWeb.trx.getAccountResources(deployerAddress);

    const balanceSun = Number(account.balance || 0);
    const minTrx = Number((preflightCfg && preflightCfg.minTrx) || 100);
    const minSun = Math.floor(minTrx * 1_000_000);

    const freeNet = Number(resources.freeNetLimit || account.free_net_limit || 0);
    const freeNetUsed = Number(resources.freeNetUsed || account.free_net_usage || 0);
    const stakedNet = Number(resources.NetLimit || account.NetLimit || 0);
    const stakedNetUsed = Number(resources.NetUsed || account.NetUsed || 0);
    const bandwidthAvailable = Math.max(0, freeNet - freeNetUsed) + Math.max(0, stakedNet - stakedNetUsed);

    const energyLimit = Number(resources.EnergyLimit || 0);
    const energyUsed = Number(resources.EnergyUsed || 0);
    const energyAvailable = Math.max(0, energyLimit - energyUsed);

    console.log(
        `[tron] preflight: balance=${fromSun(balanceSun)} TRX, bandwidth=${bandwidthAvailable}, energy=${energyAvailable}`
    );

    if (balanceSun < minSun) {
        throw new Error(`[tron] insufficient TRX balance for deployment: ${fromSun(balanceSun)} TRX < ${minTrx} TRX`);
    }
}

function selectorByName(abi, fnName) {
    const fn = abi.find((x) => x.type === 'function' && x.name === fnName);
    if (!fn) throw new Error(`[tron] function ${fnName} not found in ABI`);

    const canonicalType = (input) => {
        const t = String(input.type || '');
        const tupleSuffix = t.slice('tuple'.length); // '', '[]', '[2]', ...
        if (!t.startsWith('tuple')) return t;
        const components = input.components || [];
        const inner = components.map((c) => canonicalType(c)).join(',');
        return `(${inner})${tupleSuffix}`;
    };

    const sig = `${fn.name}(${(fn.inputs || []).map((x) => canonicalType(x)).join(',')})`;
    return tronWeb.sha3(sig).slice(0, 10);
}

function selectorsByNames(abi, names) {
    return names.map((name) => selectorByName(abi, name));
}

async function deployProxy(contractArtifact, implAddress, initArgs) {
    const proxy = await ERC1967Proxy.new(implAddress, '0x');
    const proxied = await contractArtifact.at(proxy.address);
    await proxied.initialize(...initArgs);
    return proxied;
}

async function addFacet(diamond, facetAddress, facetAbi, functionNames) {
    const facetCuts = [[facetAddress, 0, selectorsByNames(facetAbi, functionNames)]];
    await diamond.diamondCut(facetCuts, ZERO_TRON, '0x');
}

module.exports = function (deployer, network, fromOrAccounts) {
    return deployer.then(async () => {
        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}" in tron/config/deployConfig.js`);
        }
        const setupCfg = networkCfg.deploySetup || {};
        if (setupCfg.enabled === false) {
            console.log('[tron] Skip deploy setup flow (deploySetup.enabled=false).');
            return;
        }

        // TronBox docs indicate the 3rd argument is `from`; some runtimes may pass an accounts list.
        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);
        await preflightResources(deployerAddress, setupCfg.preflight);
        const owner = tryToTronHexAddress(setupCfg.owner) || deployerAddress;
        const guardian = tryToTronHexAddress(setupCfg.guardian) || owner;
        const feeReceiver = tryToTronHexAddress(setupCfg.feeReceiver) || owner;
        const weth = tryToTronHexAddress(setupCfg.wethAddress) || owner;
        const lzEndpointRaw = String(setupCfg.lzEndpoint || '').trim();
        const lzEndpoint = isZeroAddress(lzEndpointRaw) ? '' : tryToTronHexAddress(lzEndpointRaw);
        if (lzEndpointRaw && !lzEndpoint) {
            console.warn('[tron] invalid lzEndpoint in deployConfig, fallback to DebtToken without LZ endpoint');
        }
        if (lzEndpoint) {
            console.log(`[tron] DebtToken mode: DebtTokenWithLz (lzEndpoint=${toTronBase58Address(lzEndpoint)})`);
        } else {
            console.log('[tron] DebtToken mode: DebtToken (no lzEndpoint)');
        }

        const debtTokenName = setupCfg.debtTokenName || 'Satoshi Stablecoin V2';
        const debtTokenSymbol = setupCfg.debtTokenSymbol || 'satUSD';
        const minNetDebt = setupCfg.minNetDebt || '10000000000000000000';
        const debtGasCompensation = setupCfg.debtGasCompensation || '2000000000000000000';
        const spClaimStartTime = setupCfg.spClaimStartTime || '4294967295';
        const spAllocation = setupCfg.spAllocation || '0';
        const spRewardRate = setupCfg.spRewardRate || '0';

        console.log(`[tron] DeploySetup flow on ${network}`);
        console.log(`[tron] deployer=${deployerAddress}`);
        console.log(`[tron] owner=${owner}`);

        const sortedTrovesImpl = await SortedTroves.new();
        const sortedTrovesBeacon = await UpgradeableBeacon.new(sortedTrovesImpl.address, owner);
        const troveManagerImpl = await TroveManager.new();
        const troveManagerBeacon = await UpgradeableBeacon.new(troveManagerImpl.address, owner);
        const initializer = await Initializer.new();
        const satoshiXApp = await SatoshiXApp.new();

        const coreFacet = await CoreFacet.new();
        await addFacet(satoshiXApp, coreFacet.address, CoreFacet.abi, [
            'setFeeReceiver',
            'setRewardManager',
            'setPaused',
            'feeReceiver',
            'rewardManager',
            'paused',
            'startTime',
            'debtToken',
            'gasCompensation',
            'sortedTrovesBeacon',
            'troveManagerBeacon',
            'communityIssuance',
        ]);

        const borrowerOperationsFacet = await BorrowerOperationsFacet.new();
        await addFacet(satoshiXApp, borrowerOperationsFacet.address, BorrowerOperationsFacet.abi, [
            'addColl',
            'adjustTrove',
            'checkRecoveryMode',
            'closeTrove',
            'fetchBalances',
            'getCompositeDebt',
            'getGlobalSystemBalances',
            'getTCR',
            'isApprovedDelegate',
            'minNetDebt',
            'openTrove',
            'removeTroveManager',
            'repayDebt',
            'setDelegateApproval',
            'setMinNetDebt',
            'troveManagersData',
            'withdrawColl',
            'withdrawDebt',
            'forceResetTM',
        ]);

        const factoryFacet = await FactoryFacet.new();
        await addFacet(satoshiXApp, factoryFacet.address, FactoryFacet.abi, [
            'deployNewInstance',
            'troveManagerCount',
            'troveManagers',
            'setTMRewardRate',
            'maxTMRewardRate',
        ]);

        const liquidationFacet = await LiquidationFacet.new();
        await addFacet(satoshiXApp, liquidationFacet.address, LiquidationFacet.abi, [
            'batchLiquidateTroves',
            'liquidate',
            'liquidateTroves',
        ]);

        const priceFeedAggregatorFacet = await PriceFeedAggregatorFacet.new();
        await addFacet(satoshiXApp, priceFeedAggregatorFacet.address, PriceFeedAggregatorFacet.abi, [
            'fetchPrice',
            'fetchPriceUnsafe',
            'setPriceFeed',
            'oracleRecords',
        ]);

        const stabilityPoolFacet = await StabilityPoolFacet.new();
        await addFacet(satoshiXApp, stabilityPoolFacet.address, StabilityPoolFacet.abi, [
            'claimCollateralGains',
            'provideToSP',
            'startCollateralSunset',
            'withdrawFromSP',
            'accountDeposits',
            'collateralGainsByDepositor',
            'collateralTokens',
            'currentEpoch',
            'currentScale',
            'depositSnapshots',
            'depositSums',
            'epochToScaleToG',
            'epochToScaleToSums',
            'getCompoundedDebtDeposit',
            'getDepositorCollateralGain',
            'getTotalDebtTokenDeposits',
            'indexByCollateral',
            'claimableReward',
            'claimReward',
            'setClaimStartTime',
            'isClaimStart',
            'rewardRate',
            'setSPRewardRate',
            'P',
            'setRewardRate',
        ]);

        const nexusYieldManagerFacet = await NexusYieldManagerFacet.new();
        await addFacet(satoshiXApp, nexusYieldManagerFacet.address, NexusYieldManagerFacet.abi, [
            'setAssetConfig',
            'sunsetAsset',
            'swapIn',
            'pause',
            'resume',
            'setPrivileged',
            'transferTokenToPrivilegedVault',
            'previewSwapOut',
            'previewSwapIn',
            'swapOutPrivileged',
            'swapInPrivileged',
            'scheduleSwapOut',
            'withdraw',
            'convertDebtTokenToAssetAmount',
            'convertAssetToDebtTokenAmount',
            'feeIn',
            'feeOut',
            'debtTokenMintCap',
            'dailyDebtTokenMintCap',
            'debtTokenMinted',
            'isUsingOracle',
            'swapWaitingPeriod',
            'debtTokenDailyMintCapRemain',
            'pendingWithdrawal',
            'pendingWithdrawals',
            'isNymPaused',
            'dailyMintCount',
            'isAssetSupported',
            'getAssetConfig',
        ]);

        const oshiTokenImpl = await OSHIToken.new();
        const oshiToken = await deployProxy(OSHIToken, oshiTokenImpl.address, [owner]);

        const gasPool = await GasPool.new();

        const debtTokenImpl = lzEndpoint ? await DebtTokenWithLz.new(lzEndpoint) : await DebtToken.new();
        const debtTokenArtifact = lzEndpoint ? DebtTokenWithLz : DebtToken;
        const debtToken = await deployProxy(debtTokenArtifact, debtTokenImpl.address, [
            debtTokenName,
            debtTokenSymbol,
            toTronBase58Address(gasPool.address),
            toTronBase58Address(satoshiXApp.address),
            toTronBase58Address(owner),
            debtGasCompensation,
        ]);
        const debtTokenSatoshiXApp = toTronHexAddress(await debtToken.satoshiXApp());
        if (debtTokenSatoshiXApp.toLowerCase() !== satoshiXApp.address.toLowerCase()) {
            throw new Error(
                `[tron] debtToken.satoshiXApp mismatch after initialize. expected=${toTronBase58Address(satoshiXApp.address)}, ` +
                    `actual=${toTronBase58Address(debtTokenSatoshiXApp)}`
            );
        }

        const communityIssuanceImpl = await CommunityIssuance.new();
        const communityIssuance = await deployProxy(CommunityIssuance, communityIssuanceImpl.address, [
            owner,
            oshiToken.address,
            satoshiXApp.address,
        ]);

        const rewardManagerImpl = await RewardManager.new();
        const rewardManager = await deployProxy(RewardManager, rewardManagerImpl.address, [
            owner,
            satoshiXApp.address,
            weth,
            debtToken.address,
            oshiToken.address,
        ]);

        const vaultManagerImpl = await VaultManager.new();
        const vaultManager = await deployProxy(VaultManager, vaultManagerImpl.address, [
            debtToken.address,
            satoshiXApp.address,
            owner,
        ]);

        const peripheryImpl = await SatoshiPeriphery.new();
        const satoshiPeriphery = await deployProxy(SatoshiPeriphery, peripheryImpl.address, [
            debtToken.address,
            satoshiXApp.address,
            owner,
        ]);

        const swapRouterImpl = await SwapRouter.new();
        const swapRouter = await deployProxy(SwapRouter, swapRouterImpl.address, [
            debtToken.address,
            satoshiXApp.address,
            owner,
        ]);

        const hintHelpers = await MultiCollateralHintHelpers.new(satoshiXApp.address);
        const multiTroveGetter = await MultiTroveGetter.new();
        const troveHelper = await TroveHelper.new();
        const troveManagerGetter = await TroveManagerGetter.new(satoshiXApp.address);

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
                toEvmAddress(debtToken.address),
                toEvmAddress(communityIssuance.address),
                toEvmAddress(sortedTrovesBeacon.address),
                toEvmAddress(troveManagerBeacon.address),
                toEvmAddress(gasPool.address),
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

        const canRunOwnerConfig = owner.toLowerCase() === deployerAddress.toLowerCase();
        if (canRunOwnerConfig) {
            await debtToken.rely(satoshiXApp.address);
            const coreAsDiamond = await CoreFacet.at(satoshiXApp.address);
            await coreAsDiamond.setRewardManager(rewardManager.address);
            await communityIssuance.setAllocated([satoshiXApp.address], [spAllocation]);
            const spAsDiamond = await StabilityPoolFacet.at(satoshiXApp.address);
            await spAsDiamond.setClaimStartTime(spClaimStartTime);
            await spAsDiamond.setSPRewardRate(spRewardRate);
        } else {
            console.warn(
                '[tron] owner != deployer, skipped owner-only config: rely, setRewardManager, setAllocated, setClaimStartTime, setSPRewardRate'
            );
        }

        const deployment = normalizeOutputAddresses({
            network,
            deployer: deployerAddress,
            owner,
            guardian,
            feeReceiver,
            // Keep empty string when not configured, so output mirrors deployConfig intent.
            lzEndpoint: lzEndpoint || '',
            satoshiXApp: satoshiXApp.address,
            borrowerOperationsFacet: borrowerOperationsFacet.address,
            coreFacet: coreFacet.address,
            factoryFacet: factoryFacet.address,
            liquidationFacet: liquidationFacet.address,
            priceFeedAggregatorFacet: priceFeedAggregatorFacet.address,
            stabilityPoolFacet: stabilityPoolFacet.address,
            nexusYieldManagerFacet: nexusYieldManagerFacet.address,
            initializer: initializer.address,
            satoshiPeriphery: satoshiPeriphery.address,
            swapRouter: swapRouter.address,
            gasPool: gasPool.address,
            debtToken: debtToken.address,
            communityIssuance: communityIssuance.address,
            oshiToken: oshiToken.address,
            sortedTrovesBeacon: sortedTrovesBeacon.address,
            troveManagerBeacon: troveManagerBeacon.address,
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
        console.log(`[tron] deploy setup output written: ${outputPath}`);
    });
};
