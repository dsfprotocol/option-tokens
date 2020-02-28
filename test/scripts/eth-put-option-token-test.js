const ETHPutOptionToken = artifacts.require('ETHPutOptionToken')
const Factory = artifacts.require('OptionTokenFactory')
const USD = artifacts.require('DefaultBalanceToken')
const moment = require('moment')
const { expect } = require('chai')

const { toBN, fromWei, toWei } = web3.utils

console.log('Begin put option token test')

contract('Put Option Tokens | OptionTokenFactory', accounts => {
    const today = moment().unix() - (moment().unix() % 86400) + 43200

    console.log('Begin describe')

    let from, factory, expiration, strike, usd, token

    before(async () => {
        from = accounts[0]
        factory = await Factory.deployed()
        expiration = today + 86400 * 7
        strike = toWei('200').toString()
        usd = await USD.deployed()
    })

    it('writes a put option token', async () => {
        const amount = toWei('1').toString()

        const usdCost = toBN('1').mul(toBN(strike)).toString()
        debugger
        const approval = await usd.approve(factory.address, usdCost);
        const result = await factory.writePut(expiration, strike, amount)

        console.log(`-- Gas Report --
Approve Cost:     ${approval.receipt.gasUsed}
Deploy Cost:      ${result.receipt.gasUsed}
Total Write Cost: ${approval.receipt.gasUsed + result.receipt.gasUsed}
`)
        console.log('gas used for new token:', result.receipt.gasUsed)

        token = await ETHPutOptionToken.at(result.logs[0].args.token)
        const balance = await token.balanceOf(from)
        const written = await token.writers(from)
        expect(fromWei(written)).to.eq('1')
        expect(fromWei(balance)).to.eq('1')

        await usd.approve(factory.address, usdCost);
        const existingTokenResult = await factory.writePut(expiration, strike, amount)

        console.log('gas used for existing token:', existingTokenResult.receipt.gasUsed)
    })

    it('closes an option token', async () => {
        const result = await token.close(toWei('2').toString())
        console.log('close token gas:', result.receipt.gasUsed)
        const balance = await token.balanceOf(from)
        const written = await token.balanceOf(from)
        const totalWritten = await token.written()
        expect(fromWei(balance)).to.eq('0')
        expect(fromWei(written)).to.eq('0')
        expect(fromWei(totalWritten)).to.eq('0')
    })

    it('can exercise an option token', async () => {
        const holder = accounts[1]
        const amount = toWei('1')
        await usd.approve(token.address, toBN('1').mul(toBN(strike)).toString())
        await token.write(amount, { from })
        await token.transfer(holder, amount, { from })

        const holderBalance = await token.balanceOf(holder)
        expect(fromWei(holderBalance)).to.eq('1')

        const result = await token.exercise({ value: amount, from: holder })
        console.log('exercise gas:', result.receipt.gasUsed)

        const newBalance = await token.balanceOf(holder)
        const usdBalance = await usd.balanceOf(holder)
        expect(fromWei(newBalance)).to.eq('0')
        expect(fromWei(usdBalance)).to.eq('1000200')
    })
})