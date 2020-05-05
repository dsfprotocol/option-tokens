const Migrations = artifacts.require("Migrations");
const ERC20 = artifacts.require('ERC20')
const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
const ETHPutOptionToken = artifacts.require('ETHPutOptionToken')
const ETHCallOptionTokenProxy = artifacts.require('ETHCallOptionTokenProxy')
const ETHPutOptionTokenProxy = artifacts.require('ETHPutOptionTokenProxy')
const OptionTokenFactory = artifacts.require('OptionTokenFactory')
const DefaultBalanceToken = artifacts.require('DefaultBalanceToken')
const DSFToken = artifacts.require('dsf-token/DecentralizedSettlementFacilityToken')
const DateTime = artifacts.require('DateTime')
const Namesake = artifacts.require('OptionTokenNamesake')


const { toChecksumAddress } = require('ethereum-checksum-address')
const RLP = require('rlp')

async function doDeploy(deployer, network) {

  let usd
  console.log(network)
  if (network === 'develop') {
    usd = await deployer.deploy(DefaultBalanceToken)
  } else if (network === 'kovan') {
    usd = await ERC20.at('0x08ae34860fbfe73e223596e65663683973c72dd3')
  } else if (network === 'main') {
    usd = await ERC20.at('0x6b175474e89094c44da98b954eedeac495271d0f')
  } else {
    throw new Error('Network not known')
  }

  await deployer.deploy(Migrations)
  const dsf = await deployer.deploy(DSFToken)

  const sender = deployer.networks[network].from
  const factoryNonce = await web3.eth.getTransactionCount(sender) + 4
  console.log('current transaction nonce: ', factoryNonce)

  // compute and link address of OptionTokenFactory in advance
  const factoryAddressWillBe = toChecksumAddress(
    "0x" + web3.utils.sha3(RLP.encode([sender,factoryNonce])).slice(12).substring(14)
  )

  /* link factory, USD, and DSF token to Option Token Libraries */

  await ETHCallOptionToken.link('FactoryAddress', factoryAddressWillBe)
  await ETHCallOptionToken.link('DSF', dsf.address)
  await ETHCallOptionToken.link('USD', usd.address)

  await ETHPutOptionToken.link('FactoryAddress', factoryAddressWillBe)
  await ETHPutOptionToken.link('DSF', dsf.address)
  await ETHPutOptionToken.link('USD', usd.address)

  /* End Link */


  /* Deploy ETH Option Token Libraries */

  const callToken = await deployer.deploy(ETHCallOptionToken);
  const putToken = await deployer.deploy(ETHPutOptionToken);

  /* End Deploy */

  /* Deploy Namesake Contract */
  const datetime = await deployer.deploy(DateTime)
  await Namesake.link('DateTime', datetime.address)
  const namesake = await deployer.deploy(Namesake)
  /* End namesake */

  /* Link Option Token Libraries to Option Token Factory */
  await OptionTokenFactory.link('OptionTokenNamesake', namesake.address)
  await OptionTokenFactory.link('USD', usd.address)
  await OptionTokenFactory.link('ETHCallOptionTokenAddress', callToken.address)
  await OptionTokenFactory.link('ETHPutOptionTokenAddress', putToken.address)
  /* End Link */

  /* Deploy Option Token Factory */
  const factory = await deployer.deploy(OptionTokenFactory)

  console.log('linked factory address:', factoryAddressWillBe, '.  actual:', factory.address)

  if (factoryAddressWillBe !== factory.address) {
    throw new Error('Deploy failed! The Option Token Factory was not deployed at the correct address!')
  }
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
