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

        const result = await factory.writeCall(expiration, strike, {
            value: web3.utils.toWei('1').toString()
        })

        console.log('gas used for new token:', result.receipt.gasUsed)

        const token = await ETHCallOptionToken.at(result.logs[0].args.token)
        const balance = await token.balances.call(from)

        expect(web3.utils.fromWei(balance)).to.eq('1')

        const existingTokenResult = await factory.writeCall(expiration, strike, {
            value: web3.utils.toWei('1').toString()
        })

        console.log('gas used for existing token:', existingTokenResult.receipt.gasUsed)
    })
})