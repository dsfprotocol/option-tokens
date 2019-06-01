const Migrations = artifacts.require("Migrations");
const DSFProtocol = artifacts.require('DSFProtocol')
const USDMock = artifacts.require('USDMock')
const DSFTokenMock = artifacts.require('DSFTokenMock')

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  return deployer.deploy(DSFTokenMock).then(token => {
    return deployer.deploy(USDMock).then(usd => {
      return deployer.deploy(DSFProtocol, token.address, usd.address);
    })
  })
};
