const Migrations = artifacts.require("Migrations");
const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
const ETHPutOptionToken = artifacts.require('ETHPutOptionToken')
const ETHCallOptionTokenProxy = artifacts.require('ETHCallOptionTokenProxy')
const ETHPutOptionTokenProxy = artifacts.require('ETHPutOptionTokenProxy')
const OptionTokenFactory = artifacts.require('OptionTokenFactory')

const RLP = require('rlp')

async function doDeploy(deployer, network) {
  await deployer.deploy(Migrations);

  const sender = deployer.networks[network].from
  const factoryNonce = await web3.eth.getTransactionCount(sender) + 2
  console.log('current transaction nonce: ', factoryNonce)

  // compute and link address of OptionTokenFactory in advance
  const factoryAddressWillBe = "0x" + web3.utils.sha3(RLP.encode([sender,factoryNonce])).slice(12).substring(14)
  await ETHCallOptionToken.link('FactoryAddress', factoryAddressWillBe)
  await ETHPutOptionToken.link('FactoryAddress', factoryAddressWillBe)
  // TODO make the below addresses the correct factory address
  const callToken = await deployer.deploy(ETHCallOptionToken);
  const putToken = await deployer.deploy(ETHPutOptionToken);

  await OptionTokenFactory.link('ETHCallOptionTokenAddress', callToken.address)
  await OptionTokenFactory.link('ETHPutOptionTokenAddress', putToken.address)
  const factory = await deployer.deploy(OptionTokenFactory)

  console.log('linked factory address:', factoryAddressWillBe, '.  actual:', factory.address)
}

module.exports = (deployer, network) => {
  deployer.then(async () => {
    await doDeploy(deployer, network)
  })
}


// const DefaultBalanceToken = artifacts.require('default-balance-token/DefaultBalanceToken')
// const DSFToken = artifacts.require('dsf-token/DecentralizedSettlementFacilityToken')
// const OptionTokenFactory = artifacts.require('OptionTokenFactory')
// const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
// const ETHPutOptionToken = artifacts.require('ETHPutOptionToken')
// const TokenLib = artifacts.require('TokenLib')

// const CallProxy = artifacts.require('ETHCallOptionTokenProxy')
// const PutProxy = artifacts.require('ETHPutOptionTokenProxy')

// module.exports = async function(deployer) {
//   await deployer.deploy(Migrations)
//   await deployer.deploy(DefaultBalanceToken)
//   await deployer.deploy(DSFToken)

//   const registry = await deployer.deploy(OptionTokenRegistry)
//   const RegistryLib = artifacts.require('RegistryLib').at(registry.address)

//   const callOptionToken = await deployer.deploy(ETHCallOptionToken)
//   const putOptionToken = await deployer.deploy(ETHPutOptionToken)

//   CallProxy.link('TokenLib', callOptionToken.address, deployer)
//   CallProxy.link('RegistryLib', registry.address, deployer)
//   // deployer.link(TokenLib.at(callOptionToken.address), CallProxy)
//   // deployer.link(RegistryLib, CallProxy)
//   await deployer.deploy(CallProxy)

//   // deployer.link(TokenLib.at(putOptionToken), PutProxy)
//   // deployer.link(RegistryLib, PutProxy)
//   // await deployer.deploy(PutProxy)
// };
