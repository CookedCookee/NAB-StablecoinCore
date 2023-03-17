# NAB-StablecoinCore
National Australia Bank's deployed StablecoinCoreV1 implementation.

### Deployments
Ethereum Mainnet
- Global Control: [0x7d1289806aa974c6b626fa17d30676ddf7ed31cb](https://etherscan.io/address/0x7d1289806aa974c6b626fa17d30676ddf7ed31cb#code)
- StablecoinCoreV1: [0x14c46a24045EdCe3B3018902C9590CD5db8e1fE2](https://etherscan.io/address/0x14c46a24045edce3b3018902c9590cd5db8e1fe2#code)
- AUDN: [0xC035386af88e78B0E1C8E248Ecf4142AE3e6956f](https://etherscan.io/address/0xc035386af88e78b0e1c8e248ecf4142ae3e6956f#code)
- EURN: [0x550A31868a03d126FEe937d33281473B4147A22A](https://etherscan.io/address/0x550a31868a03d126fee937d33281473b4147a22a#code)
- GPNN: [0x01168290573d83529864Cf017141CF4fD4C060d3](https://etherscan.io/address/0x01168290573d83529864cf017141cf4fd4c060d3#code)
- JPYN: [0x87A8a720106C0EFA6DF528b0762fc9Ab8AF9bCf3](https://etherscan.io/address/0x87a8a720106c0efa6df528b0762fc9ab8af9bcf3#code)
- NZDN: [0xfCF588002f8CE1112584B7F7CAD19cB63E3041e6](https://etherscan.io/address/0xfcf588002f8ce1112584b7f7cad19cb63e3041e6#code)
- SGDN: [0xCA37348D30960115b31e55B715617Cb27b18e32E](https://etherscan.io/address/0xca37348d30960115b31e55b715617cb27b18e32e)
- USDN: [0xaA3C4B459e20bb5AD3724F6db86A0b687Ec5c32a](https://etherscan.io/address/0xaa3c4b459e20bb5ad3724f6db86a0b687ec5c32a#code)

### Installation
- Clone the repo
- Follow all instructions on this [page](https://hardhat.org/tutorial/creating-a-new-hardhat-project) beginning from run `yarn init`
- Install OpenZeppelin contracts via command from root of repo `yarn add --dev @openzeppelin/contracts @openzeppelin/hardhat-upgrades @openzeppelin/contracts-upgradeable`
- Ensure that your compiler has enabled using the optimiser on `hardhat.config.js`. More general information found [here](https://hardhat.org/hardhat-runner/docs/guides/compile-contracts), [here](https://docs.openzeppelin.com/upgrades-plugins/1.x/hardhat-upgrades) regarding the hardhat upgrades, and [here](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) regarding openzeppelin upgradable contracts.
- For live deployment follow all instructions on this [page](https://hardhat.org/tutorial/deploying-to-a-live-network). More information regarding deployment and verification found [here](https://hardhat.org/hardhat-runner/docs/guides/deploying) and [here](https://hardhat.org/hardhat-runner/docs/guides/verifying)

### Testing
Local testing via command `npx hardhat test`

### Troubleshooting

Encountering either `Error: Package subpath './lib/utils'...` or `ethers typeerror: cannot read properties of undefined (reading 'jsonrpcprovider')` can be resolved by using an earlier version of ethers. 

1. Delete `node_modules`
2. Run: `yarn add ethers@5.7.2`