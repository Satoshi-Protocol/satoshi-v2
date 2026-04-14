const fs = require('fs');
const path = require('path');

/**
 * Validate and normalise a config value to an unsigned integer string.
 * @param {*} value      - The raw config value.
 * @param {string} fallback - Default string to use when value is empty/undefined/null.
 * @param {string} fieldName - Field name used in the error message.
 * @param {string} [context] - Optional context prefix for the error message (e.g. 'deployInstance').
 */
function uintString(value, fallback, fieldName, context) {
    const raw = value === undefined || value === null || value === '' ? fallback : value;
    const normalized = String(raw).trim();
    if (!/^\d+$/.test(normalized)) {
        const prefix = context ? `[tron] ${context}.` : '[tron] ';
        throw new Error(`${prefix}${fieldName} must be an unsigned integer string. got="${value}"`);
    }
    return normalized;
}

/**
 * Read a previously saved deploysetup output JSON from tron/deployments/<network>.deploysetup.json.
 * Returns null if the file does not exist.
 * @param {string} network
 */
function readDeploySetupOutput(network) {
    const p = path.join(__dirname, '..', '..', 'deployments', `${network}.deploysetup.json`);
    if (!fs.existsSync(p)) return null;
    return JSON.parse(fs.readFileSync(p, 'utf8'));
}

module.exports = { uintString, readDeploySetupOutput };
