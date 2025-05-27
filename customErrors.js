const fs = require('fs');
const path = require('path');
const { keccak256, toUtf8Bytes } = require('ethers');

const contractDir = './src';
let result = [['Contract', 'Error Name', 'Selector']];

function getErrorSelector(signature) {
    return keccak256(toUtf8Bytes(signature)).slice(0, 10); // bytes4 is 4 bytes = 8 hex chars + '0x'
}

function extractErrors(content) {
    const regex = /error\s+(\w+)\s*\((.*?)\)/g;
    let match, errors = [];
    while ((match = regex.exec(content)) !== null) {
        const name = match[1];
        const args = match[2].replace(/\s+/g, ''); // remove whitespace
        errors.push({ name, signature: `${name}(${args})` });
    }
    return errors;
}

function processFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const errors = extractErrors(content);
    const relativePath = path.relative(contractDir, filePath);
    for (const err of errors) {
        const selector = getErrorSelector(err.signature);
        result.push([relativePath, err.signature, selector]);
    }
}

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        const fullPath = path.join(dir, f);
        if (fs.statSync(fullPath).isDirectory()) {
            walkDir(fullPath, callback);
        } else if (fullPath.endsWith('.sol')) {
            callback(fullPath);
        }
    });
}

walkDir(contractDir, processFile);

fs.writeFileSync('errors.csv', result.map(row => row.join(',')).join('\n'));
console.log('Saved to errors.csv');
