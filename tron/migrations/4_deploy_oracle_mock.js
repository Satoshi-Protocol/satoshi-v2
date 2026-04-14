const fs = require('fs');
const path = require('path');
const deployConfig = require('../config/deployConfig');
const addressUtils = require('./utils/address');

const OracleMock = artifacts.require('OracleMock');
const toTronHexAddress = (value) => addressUtils.toTronHexAddress(value, tronWeb);
const toTronBase58Address = (value) => addressUtils.toTronBase58Address(value, tronWeb);
const normalizeOutputAddresses = (value) => addressUtils.normalizeOutputAddresses(value, tronWeb);

module.exports = function (deployer, network, fromOrAccounts) {
    return deployer.then(async () => {
        const networkCfg = (deployConfig.networks || {})[network];
        if (!networkCfg) {
            throw new Error(`[tron] missing network config for "${network}" in tron/config/deployConfig.js`);
        }

        const cfg = networkCfg.deployOracleMock || {};
        if (!cfg.enabled) {
            console.log('[tron] Skip deploy OracleMock flow (deployOracleMock.enabled=false).');
            return;
        }

        const decimals = Number(cfg.decimals ?? 18);
        const version = String(cfg.version ?? '1');
        const maxTimeThreshold = String(cfg.maxTimeThreshold ?? '8640000');
        const initialAnswer = String(cfg.initialAnswer ?? '100000000000000000000000');
        if (!Number.isInteger(decimals) || decimals < 0 || decimals > 255) {
            throw new Error('[tron] deployOracleMock.decimals must be an integer in [0,255].');
        }
        if (BigInt(maxTimeThreshold) <= 120n) {
            throw new Error('[tron] deployOracleMock.maxTimeThreshold must be > 120.');
        }
        if (BigInt(initialAnswer) <= 0n) {
            throw new Error('[tron] deployOracleMock.initialAnswer must be > 0.');
        }

        const deployerAccount = Array.isArray(fromOrAccounts)
            ? fromOrAccounts[0]
            : typeof fromOrAccounts === 'string'
              ? fromOrAccounts
              : networkCfg.deployer;
        const deployerAddress = toTronHexAddress(deployerAccount);

        const outputDir = path.join(__dirname, '..', 'deployments');
        fs.mkdirSync(outputDir, { recursive: true });
        const outputPath = path.join(outputDir, `${network}.oraclemock.json`);
        const persistOutput = (obj) => {
            const output = normalizeOutputAddresses(obj);
            fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
            return output;
        };

        const oracleMock = await OracleMock.new(decimals, version);

        // Keep constructor defaults unless caller explicitly requests an override.
        await oracleMock.updateMaxTimeThreshold(maxTimeThreshold);
        const nowSec = Math.floor(Date.now() / 1000);
        await oracleMock.updateRoundData([initialAnswer, String(nowSec), String(nowSec), '1']);
        await oracleMock.fetchPrice();

        const latestRoundData = await oracleMock.latestRoundData();

        persistOutput({
            network,
            deployer: deployerAddress,
            oracleMock: oracleMock.address,
            source: oracleMock.address,
            decimals,
            version,
            maxTimeThreshold,
            initialAnswer,
            latestRoundId: latestRoundData[0]?.toString?.() ?? String(latestRoundData[0]),
            latestAnswer: latestRoundData[1]?.toString?.() ?? String(latestRoundData[1]),
            latestStartedAt: latestRoundData[2]?.toString?.() ?? String(latestRoundData[2]),
            latestUpdatedAt: latestRoundData[3]?.toString?.() ?? String(latestRoundData[3]),
            latestAnsweredInRound: latestRoundData[4]?.toString?.() ?? String(latestRoundData[4]),
        });

        console.log('[tron] DeployOracleMock completed');
        console.log(`[tron] oracleMock=${toTronBase58Address(oracleMock.address)}`);
        console.log(`[tron] source=${toTronBase58Address(oracleMock.address)}`);
        console.log(`[tron] decimals=${decimals}`);
        console.log(`[tron] version=${version}`);
        console.log(`[tron] maxTimeThreshold=${maxTimeThreshold}`);
        console.log(`[tron] deploy output written: ${outputPath}`);
    });
};
