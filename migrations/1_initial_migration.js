const Migrations = artifacts.require("Migrations");
const DefaultBalanceToken = artifacts.require('default-balance-token/DefaultBalanceToken')
const DSFToken = artifacts.require('dsf-token/DecentralizedSettlementFacilityToken')
const OptionTokenFactory = artifacts.require('OptionTokenFactory')

module.exports = async function(deployer) {
  await deployer.deploy(Migrations)
  await deployer.deploy(DefaultBalanceToken)
  await deployer.deploy(DSFToken)
  await deployer.deploy(OptionTokenFactory)
};
