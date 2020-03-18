const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
const Factory = artifacts.require('OptionTokenFactory')
const moment = require('moment')
const { expect } = require('chai')
const USD = artifacts.require('DefaultBalanceToken')

const { toBN, fromWei, toWei } = web3.utils

console.log('Begin call option token test')

contract('Call Option Tokens | OptionTokenFactory', accounts => {
    const today = moment().unix() - (moment().unix() % 86400) + 43200

    console.log('Begin describe')

    let from, factory, expiration, strike, usd, token
    before(async () => {
        from = accounts[0]
        factory = await Factory.deployed()
        expiration = today + 86400 * 7
        strike = web3.utils.toWei('200').toString()
        usd = await USD.deployed()
    })

    it('writes a call option token', async () => {
        const result = await factory.writeCall(expiration, strike, {
            value: web3.utils.toWei('1').toString()
        })

        console.log('gas used for new token:', result.receipt.gasUsed)

        token = await ETHCallOptionToken.at(result.logs[0].args.token)
        const name = await token.name.call()
        const symbol = await token.symbol.call()


        expect(name).to.match(/[A-Z]{3}\s[0-9]{1,2}\s200-CALL/)
        expect(symbol).to.match(/[0-9]{1,2}\/[0-9]{1,2}\s200-C/)
        console.log('created token with name:', name, 'symbol:', symbol)

        const balance = await token.balances.call(from)

        expect(web3.utils.fromWei(balance)).to.eq('1')

        const existingTokenResult = await factory.writeCall(expiration, strike, {
            value: web3.utils.toWei('1').toString()
        })

        console.log('gas used for existing token:', existingTokenResult.receipt.gasUsed)
    })

    it('closes a call option token', async () => {
        const ethBalanceWas = await web3.eth.getBalance(from)
        const gasPrice = 1e9
        const result = await token.close(toWei('2'), { gasPrice })
        console.log('gas for closing call option:', result.receipt.gasUsed)
        const ethBalanceIs = await web3.eth.getBalance(from)

        const gasCost = result.receipt.gasUsed * gasPrice
        console.log(`-- Closing Token --
Balance Was: ${ethBalanceWas}
Balance Is:  ${ethBalanceIs}
Gas Used:    ${result.receipt.gasUsed}`)

        expect(fromWei(toBN(ethBalanceIs).sub(toBN(ethBalanceWas)).add(toBN(gasCost)))).to.eq('2')

        const balance = await token.balanceOf(from)
        const written = await token.writers(from)
        const totalWritten = await token.written()
        expect(fromWei(balance)).to.eq('0')
        expect(fromWei(written)).to.eq('0')
        expect(fromWei(totalWritten)).to.eq('0')
    })

    it('exercises a call option token', async () => {

    })
})