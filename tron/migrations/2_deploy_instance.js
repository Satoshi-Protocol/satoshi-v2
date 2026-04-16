const fs = require('fs');
const path = require('path');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');
const { uintString, readDeploySetupOutput } = require('./utils/config');

const PriceFeedAggregatorFacet = artifacts.require('PriceFeedAggregatorFacet');
const FactoryFacet = artifacts.require('FactoryFacet');
const CoreFacet = artifacts.require('CoreFacet');
const SatoshiXApp = artifacts.require('SatoshiXApp');
const RewardManager = artifacts.require('RewardManager');
const CommunityIssuance = artifacts.require('CommunityIssuance');
const VaultManager = artifacts.require('VaultManager');
const TroveManager = artifacts.require('TroveManager');
const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const toTronBase58Address = (value) => addressUtils.toTronBase58Address(value, tronWeb);
const normalizeOutputAddresses = (value) => addressUtils.normalizeOutputAddresses(value, tronWeb);

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = function (deployer, network, fromOrAccounts) {
    return deployer.then(async () => {
        // Inject TronGrid API key into existing providers (tronbox ignores headers config)
        const _apiKey = process.env.TRON_PRO_API_KEY || '';
        if (_apiKey) {
            const h = { 'TRON-PRO-API-KEY': _apiKey };
            for (const node of [tronWeb.fullNode, tronWeb.solidityNode, tronWeb.eventServer]) {
                if (node && node.instance) Object.assign(node.instance.defaults.headers, h);
                if (node) node.headers = h;
            }
        }

        let step = 1;
        const done = (message) => {
            console.log(`[tron][step ${step}] ${message}`);
            step += 1;
        };

        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}" in tron/config/deployConfig.js`);
        }
        const instanceCfg = networkCfg.deployInstance || {};
        if (!instanceCfg.enabled) {
            console.log('[tron] Skip deploy instance flow (set deployInstance.enabled=true to enable).');
            return;
        }
        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);
        const deployerBase58 = toTronBase58Address(deployerAddress);
        const txOpts = { from: deployerBase58 };
        const OWNER_ROLE = tronWeb.sha3('OWNER_ROLE');
        done(`loaded network config and deployer=${deployerBase58}`);

        const deploySetupOut = readDeploySetupOutput(network) || {};
        const satoshiXApp = toTronHexAddress(instanceCfg.satoshiXApp || deploySetupOut.satoshiXApp || '');
        const rewardManagerAddr = toTronHexAddress(instanceCfg.rewardManager || deploySetupOut.rewardManager || '');
        const vaultManagerAddr = toTronHexAddress(instanceCfg.vaultManager || deploySetupOut.vaultManager || '');
        const collateralAddress = toTronHexAddress(instanceCfg.collateralAddress);
        const priceFeedAddress = toTronHexAddress(instanceCfg.priceFeedAddress);

        if (!satoshiXApp || !rewardManagerAddr || !vaultManagerAddr || !collateralAddress || !priceFeedAddress) {
            throw new Error(
                '[tron] deployInstance requires satoshiXApp/rewardManager/vaultManager/collateralAddress/priceFeedAddress (from config or deploysetup.json).'
            );
        }
        done('resolved required addresses');

        const params = {
            minuteDecayFactor: uintString(
                instanceCfg.minuteDecayFactor,
                '999037758833783500',
                'minuteDecayFactor',
                'deployInstance'
            ),
            redemptionFeeFloor: uintString(
                instanceCfg.redemptionFeeFloor,
                '5000000000000000',
                'redemptionFeeFloor',
                'deployInstance'
            ),
            maxRedemptionFee: uintString(
                instanceCfg.maxRedemptionFee,
                '50000000000000000',
                'maxRedemptionFee',
                'deployInstance'
            ),
            borrowingFeeFloor: uintString(
                instanceCfg.borrowingFeeFloor,
                '5000000000000000',
                'borrowingFeeFloor',
                'deployInstance'
            ),
            maxBorrowingFee: uintString(
                instanceCfg.maxBorrowingFee,
                '50000000000000000',
                'maxBorrowingFee',
                'deployInstance'
            ),
            interestRateInBps: uintString(instanceCfg.interestRateInBps, '0', 'interestRateInBps', 'deployInstance'),
            maxDebt: uintString(instanceCfg.maxDebt, '1000000000000000000000000000', 'maxDebt', 'deployInstance'),
            MCR: uintString(instanceCfg.MCR, '1700000000000000000', 'MCR', 'deployInstance'),
            rewardRate: uintString(instanceCfg.rewardRate, '0', 'rewardRate', 'deployInstance'),
            OSHIAllocation: uintString(instanceCfg.oshiAllocation, '0', 'oshiAllocation', 'deployInstance'),
            claimStartTime: uintString(instanceCfg.claimStartTime, '4294967295', 'claimStartTime', 'deployInstance'),
        };
        const retainPercentage = uintString(instanceCfg.retainPercentage, '0', 'retainPercentage', 'deployInstance');
        const refillPercentage = uintString(instanceCfg.refillPercentage, '0', 'refillPercentage', 'deployInstance');
        const deploymentParamsTuple = [
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR,
            params.rewardRate,
            params.OSHIAllocation,
            params.claimStartTime,
        ];
        done('validated deployment parameters');

        const priceFeedFacet = await PriceFeedAggregatorFacet.at(satoshiXApp);
        const factoryFacet = await FactoryFacet.at(satoshiXApp);
        const rewardManager = await RewardManager.at(rewardManagerAddr);
        const coreFacet = await CoreFacet.at(satoshiXApp);
        const satoshiXAppContract = await SatoshiXApp.at(satoshiXApp);
        const hasOwnerRole = await satoshiXAppContract.hasRole(OWNER_ROLE, deployerBase58);
        if (!hasOwnerRole) {
            throw new Error(
                `[tron] deployer ${toTronBase58Address(deployerAddress)} does not have OWNER_ROLE on ${toTronBase58Address(satoshiXApp)}`
            );
        }
        const communityIssuanceAddress = toTronHexAddress(
            instanceCfg.communityIssuance || deploySetupOut.communityIssuance || (await coreFacet.communityIssuance())
        );
        const communityIssuance = await CommunityIssuance.at(communityIssuanceAddress);
        const vaultManager = await VaultManager.at(vaultManagerAddr);
        done('loaded contracts and confirmed OWNER_ROLE');

        const countBefore = Number((await factoryFacet.troveManagerCount()).toString());
        await priceFeedFacet.setPriceFeed(collateralAddress, priceFeedAddress, txOpts);
        done('setPriceFeed completed');
        let configuredOracle = '';
        for (let i = 0; i < 8; i++) {
            const oracleRecord = await priceFeedFacet.oracleRecords(collateralAddress);
            configuredOracle = toTronHexAddress(oracleRecord[0]);
            if (configuredOracle.toLowerCase() === priceFeedAddress.toLowerCase()) break;
            await sleep(1500);
        }
        if (configuredOracle.toLowerCase() !== priceFeedAddress.toLowerCase()) {
            throw new Error(
                `[tron] setPriceFeed did not update oracleRecords. expected=${toTronBase58Address(priceFeedAddress)}, ` +
                    `actual=${toTronBase58Address(configuredOracle)}`
            );
        }
        done('oracleRecords verification completed');
        try {
            await priceFeedFacet.fetchPrice(collateralAddress);
        } catch (err) {
            const reason = err && err.message ? err.message : String(err);
            throw new Error(
                `[tron] fetchPrice failed for collateral=${toTronBase58Address(collateralAddress)}, ` +
                    `priceFeed=${toTronBase58Address(priceFeedAddress)}. reason=${reason}`
            );
        }
        done('fetchPrice validation completed');

        try {
            await factoryFacet.deployNewInstance.call(
                collateralAddress,
                priceFeedAddress,
                deploymentParamsTuple,
                txOpts
            );
        } catch (err) {
            const reason = err && err.message ? err.message : String(err);
            throw new Error(`[tron] deployNewInstance dry-run reverted. reason=${reason}`);
        }
        done('deployNewInstance dry-run completed');

        const deployTx = await factoryFacet.deployNewInstance(
            collateralAddress,
            priceFeedAddress,
            deploymentParamsTuple,
            txOpts
        );
        const txResult =
            deployTx?.receipt?.result ||
            deployTx?.result ||
            deployTx?.receipt?.contractRet ||
            deployTx?.receipt?.resMessage;
        if (txResult && String(txResult).toUpperCase().includes('FAIL')) {
            throw new Error(`[tron] deployNewInstance transaction failed. txResult=${String(txResult)}`);
        }
        done('deployNewInstance transaction submitted');
        let countAfter = Number((await factoryFacet.troveManagerCount()).toString());
        for (let i = 0; i < 8 && countAfter <= countBefore; i++) {
            // Some Tron RPC providers lag a few seconds before reflecting state updates.
            await sleep(1500);
            countAfter = Number((await factoryFacet.troveManagerCount()).toString());
        }
        if (countAfter <= countBefore) {
            throw new Error(
                `[tron] deployNewInstance tx submitted but troveManagerCount did not increase after retries. ` +
                    `before=${countBefore}, after=${countAfter}, satoshiXApp=${toTronBase58Address(satoshiXApp)}. ` +
                    `Check that deployer has OWNER_ROLE on SatoshiXApp and that this config targets the correct deployment.`
            );
        }

        const troveManagerAddress = await factoryFacet.troveManagers(countAfter - 1);
        const troveManager = await TroveManager.at(troveManagerAddress);
        const sortedTrovesAddress = await troveManager.sortedTroves();
        done(`new troveManager discovered: ${toTronBase58Address(troveManagerAddress)}`);

        await rewardManager.registerTroveManager(troveManagerAddress, txOpts);
        done('rewardManager.registerTroveManager completed');
        await communityIssuance.setAllocated([troveManagerAddress], [params.OSHIAllocation], txOpts);
        done('communityIssuance.setAllocated completed');
        await troveManager.setFarmingParams(retainPercentage, refillPercentage, txOpts);
        done('troveManager.setFarmingParams completed');
        await troveManager.setVaultManager(vaultManagerAddr, txOpts);
        done('troveManager.setVaultManager completed');
        await vaultManager.setTroveManager(troveManagerAddress, true, txOpts);
        done('vaultManager.setTroveManager completed');

        const output = normalizeOutputAddresses({
            network,
            satoshiXApp,
            collateral: collateralAddress,
            priceFeed: priceFeedAddress,
            troveManager: troveManagerAddress,
            sortedTroves: sortedTrovesAddress,
            rewardManager: rewardManagerAddr,
            communityIssuance: communityIssuanceAddress,
            vaultManager: vaultManagerAddr,
            params,
            retainPercentage,
            refillPercentage,
        });

        const outputDir = path.join(__dirname, '..', 'deployments');
        fs.mkdirSync(outputDir, { recursive: true });
        const outputPath = path.join(outputDir, `${network}.instance.json`);
        fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
        done(`deployment output saved: ${outputPath}`);

        const collateralBase58 = toTronBase58Address(collateralAddress);
        const priceFeedBase58 = toTronBase58Address(priceFeedAddress);
        const troveManagerBase58 = toTronBase58Address(troveManagerAddress);
        const sortedTrovesBase58 = toTronBase58Address(sortedTrovesAddress);

        console.log(`[tron] DeployInstance completed`);
        console.log(`[tron] collateral=${collateralBase58}`);
        console.log(`[tron] priceFeed=${priceFeedBase58}`);
        console.log(`[tron] troveManager=${troveManagerBase58}`);
        console.log(`[tron] sortedTroves=${sortedTrovesBase58}`);
        console.log(`[tron] deploy instance output written: ${outputPath}`);
    });
};
