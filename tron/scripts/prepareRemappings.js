const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');

const mappings = [
    { link: 'node_modules/@solidstate/contracts', target: 'lib/solidstate-solidity/contracts' },
    { link: 'node_modules/@pythnetwork/pyth-sdk-solidity', target: 'lib/pyth-sdk-solidity' },
    { link: 'node_modules/@api3/contracts', target: 'lib/contracts/contracts' },
    {
        link: 'node_modules/@chainsight-management-oracle/contracts',
        target: 'lib/chainsight-management-oracle/contracts',
    },
    { link: 'node_modules/solmate', target: 'lib/solmate' },
];

function ensureSymlink(linkRel, targetRel) {
    const linkPath = path.join(ROOT, linkRel);
    const targetPath = path.join(ROOT, targetRel);

    if (!fs.existsSync(targetPath)) {
        throw new Error(`[tron] missing target for remapping: ${targetRel}`);
    }

    fs.mkdirSync(path.dirname(linkPath), { recursive: true });

    if (fs.existsSync(linkPath)) {
        return;
    }

    const relativeTarget = path.relative(path.dirname(linkPath), targetPath);
    fs.symlinkSync(relativeTarget, linkPath, 'dir');
    console.log(`[tron] remap linked ${linkRel} -> ${targetRel}`);
}

for (const mapping of mappings) {
    ensureSymlink(mapping.link, mapping.target);
}
