const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
const Factory = artifacts.require('OptionTokenFactory')
const moment = require('moment')
const { expect } = require('chai')

console.log('Begin call option token test')

contract('OptionTokenFactory', accounts => {
    const today = moment().unix() - (moment().unix() % 86400) + 43200

    console.log('Begin describe')

    it('writes a call option token', async () => {
        const from = accounts[0]
        const factory = await Factory.deployed()
        const expiration = today + 86400 * 7
        const strike = web3.utils.toWei('200').toString()
        debugger
        const result = await factory.writeCall(expiration, strike)

        console.log('gasUsed:', result.gasUsed)
        const token = await ETHCallOptionToken.at(result.logs[0].args.token)
        const balance = await token.balances.call(from)
        console.log(balance, balance.toString(), web3.utils.fromWei(balance))
    })
})