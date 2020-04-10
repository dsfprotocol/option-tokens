const DefaultBalanceToken = artifacts.require('DefaultBalanceToken')
const ETHCallOptionToken = artifacts.require('ETHCallOptionToken')
const Factory = artifacts.require('OptionTokenFactory')
const moment = require('moment')
const { expect } = require('chai')
const USD = artifacts.require('DefaultBalanceToken')
const AuctionParticipant = artifacts.require('AuctionParticipant')
const DSFToken = artifacts.require('dsf-token/DecentralizedSettlementFacilityToken')

const { toBN, fromWei, toWei } = web3.utils

console.log('Begin settlement test.')

contract('Call Option Tokens | Settlement', accounts => {
    const today = moment().unix() - (moment().unix() % 86400) + 43200

    console.log('Begin describe')

    let from, factory, expiration,
        strike, usd, token,
        zeroDSFBalance, auctionParticipant,
        dsfToken, holder, writer
    before(async () => {
        from = accounts[0]
        factory = await Factory.deployed()
        expiration = today + 86400 * 7
        strike = web3.utils.toWei('100').toString()
        usd = await USD.deployed()
        let address = (await factory.writeCall(expiration, strike, {
            value: web3.utils.toWei('1').toString()
        })).logs[0].args.token

        token = await ETHCallOptionToken.at(address)
        writer = accounts[0]
        holder = accounts[1]
        await token.transfer(holder, await token.balanceOf(writer))
        zeroDSFBalance = accounts[9]
        dsfToken = await DSFToken.deployed()
        auctionParticipant = await AuctionParticipant.new()
    })

    it('has no price before the expiration', async () => {
        try {
            await token.auctionPrice()
        } catch (e) {
            // expect the VM to throw, as the auction has not started yet
            expect(e.message).to.include('VM Exception')
        }
    })

    it('has no price at t=0', async () => {
        await increaseTime(expiration)
        try {
            await token.auctionPrice()
        } catch (e) {
            // expect the VM to throw, as the auction has not started yet
            expect(e.message).to.include('VM Exception')
        }
    })

    it('has a really high price at t=1', async () => {
        await increaseTime(expiration + 1)
        const price = await token.auctionPrice()
        const wei = fromWei(price)
        expect(parseFloat(wei)).to.be.gt(90000)
    })

    it('has price=150 at t=8 for zero DSF balance account', async () => {
        await increaseTime(expiration + 8 * 3600)
        const price = await token.auctionPrice({ from: zeroDSFBalance })
        const wei = fromWei(price)
        expect(parseFloat(wei)).to.be.closeTo(150, 1)
    })

    it('has accounts for DSF token settlement edge at t=8', async () => {
        const price = await token.auctionPrice()
        const wei = fromWei(price)
        // a reiteration of the price calculation formula from the contract
        const expectedPrice = 0.97 * 100 * 12 / 8 + 0.03 * 100
        expect(parseFloat(wei)).to.be.closeTo(expectedPrice, 1)
    })

    it('can be bought at t=8 by non-DSF token holder for $150', async () => {
        const balanceWas = await usd.balanceOf(auctionParticipant.address)
        await auctionParticipant.settleCall(token.address, toWei('0.1'))
        const balanceIs = await usd.balanceOf(auctionParticipant.address)
        const ethBalanceIs = fromWei(await web3.eth.getBalance(auctionParticipant.address))
        expect(ethBalanceIs).to.eq('0.1')
        expect(parseFloat(fromWei(balanceWas.sub(balanceIs)))).to.be.closeTo(0.1 * 150, 0.05)
    })

    it('can be bought at t=8 by DSF token holder for $148.50', async () => {
        await dsfToken.approve(auctionParticipant.address, await dsfToken.balanceOf(accounts[0]))
        const balanceWas = await usd.balanceOf(auctionParticipant.address)
        await auctionParticipant.settleCall(token.address, toWei('0.1'))
        const balanceIs = await usd.balanceOf(auctionParticipant.address)
        const ethBalanceIs = fromWei(await web3.eth.getBalance(auctionParticipant.address))
        const usdBalanceDiff = fromWei(balanceWas.sub(balanceIs))
        const settled = fromWei(await token.settled());
        const written = fromWei(await token.written());
        expect(settled).to.eq('0.2')
        expect(written).to.eq('1')
        expect(ethBalanceIs).to.eq('0.2')
        expect(parseFloat(usdBalanceDiff)).to.be.closeTo(0.1 * 148.50, 0.05)
    })

    it('will reject settlement of more than the available number of contracts', async () => {
        let txFailed = false
        try {
            await auctionParticipant.settleCall(token.address, toWei('0.800000000000000001'))
        } catch (e) {
            txFailed = true
        }
        expect(txFailed).to.eq(true)
    })

    it('will fail settlement if the settlement period has ended', async () => {
        increaseTime(expiration + 3600 * 12)

        let txFailed = false
        try {
            await auctionParticipant.settleCall(token.address, toWei('0.2'))
        } catch (e) {
            txFailed = true
        }
        expect(txFailed).to.eq(true)
    })

    it('will transfer holder settlement to the holder', async () => {
        await increaseTime(expiration + 3600 * 12 + 1)
        const usdBalanceWas = await usd.balanceOf(holder)
        let result = await token.assignment({ from: holder })
        console.log('gas used for holder #assignment:', result.receipt.gasUsed)
        const usdBalanceIs = await usd.balanceOf(holder)
        const diff = fromWei(usdBalanceIs.sub(usdBalanceWas))

        // this is an unfortunate hack as a result of using the DefaultBalanceToken
        // The holder actually received $9.85, which is the correct amount
        expect(parseFloat(diff)).to.be.closeTo(1000009.85, 0.05)
    })

    it('will transfer writer settlement to writer', async () => {
        const usdBalanceWas = await usd.balanceOf(writer)
        const ethBalanceWas = await web3.eth.getBalance(writer)
        const result = await token.assignment({ from: writer })
        console.log('gas used for writers #assignment:', result.receipt.gasUsed)
        const usdBalanceIs = await usd.balanceOf(writer)
        const ethBalanceIs = await web3.eth.getBalance(writer)
        const tx = await web3.eth.getTransaction(result.tx)
        expect(parseInt(ethBalanceIs - ethBalanceWas) + result.receipt.gasUsed * tx.gasPrice).to.eq(800000000000000000)
        expect(fromWei(usdBalanceIs.sub(usdBalanceWas))).to.eq('20')
    })

    async function increaseTime(to) {
        const blockNumber = await web3.eth.getBlockNumber()
        const block = await web3.eth.getBlock(blockNumber)

        await web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [to - block.timestamp],
            id: 0
        }, () => {})

        await web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: 0
        }, () => {})

        return await web3.eth.getBlock(blockNumber + 1)
    }
})