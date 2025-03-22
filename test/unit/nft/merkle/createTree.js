const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");
const path = require('path');

let fileName = "merkleInput.json";
let filePath =  path.join(__dirname, fileName);

const parsedFile = JSON.parse(fs.readFileSync(filePath, 'utf8'));
let items = parsedFile.data.length;

let data = [];
for (let i = 0; i < items; ++i) {
  data.push(
    [parsedFile.data[i].user.toString(), parsedFile.data[i].token.toString()]
  )
}
      
const tree = StandardMerkleTree.of(data, ["address", "uint256"]);
const root = tree.root;
const treeData = tree.dump();

for (const [i, v] of tree.entries()) {
  const proof = tree.getProof(i);
  treeData.values[i].user = treeData.values[i].value[0];
  treeData.values[i].token = parseInt(treeData.values[i].value[1]);
  treeData.values[i].proof = proof;
}

fs.writeFileSync(`result/root.json`, JSON.stringify({ "root": root }));
fs.writeFileSync(`result/tree.json`, JSON.stringify(treeData));