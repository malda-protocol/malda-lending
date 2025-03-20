const fs = require("fs");

const addresses = fs.readFileSync('rawList.txt', 'utf-8')
    .split('\n')
    .map(addr => addr.trim())
    .filter(addr => addr.length > 0);

const data = addresses.map((address, index) => ({
    user: `0x${address.padStart(40, '0')}`,
    token: (index + 1).toString()
}));


const output = { data };

fs.writeFileSync('output.json', JSON.stringify(output, null, 4), 'utf-8');

console.log('JSON file generated: output.json');