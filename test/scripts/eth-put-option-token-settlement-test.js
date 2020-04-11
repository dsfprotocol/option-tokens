const ETHPutOptionToken = artifacts.require('ETHPutOptionToken')
const Factory = artifacts.require('OptionTokenFactory')
const moment = require('moment')
const { expect } = require('chai')
const USD = artifacts.require('DefaultBalanceToken')
const AuctionParticipant = artifacts.require('AuctionParticipant')
const DSFToken = artifacts.require('dsf-token/DecentralizedSettlementFacilityToken')

const { fromWei, toWei } = web3.utils

console.log('Begin settlement test.')

contract('Put Option Tokens | Settlement', accounts => {
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
        strike = toWei('100')
        usd = await USD.deployed()
        await usd.approve(factory.address, strike)

        let address = (await factory.writePut(expiration, strike, toWei('1'))).logs[0].args.token

        token = await ETHPutOptionToken.at(address)
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
        const block = await increaseTime(expiration + 1)
        const elapsed = block.timestamp - expiration
        const price = await token.auctionPrice()
        console.log('elapsed:', elapsed)
        const wei = fromWei(price)
        const expectedPrice = 0.97001 * 43200 / (100 * elapsed) + 0.02999 / 100
        expect(parseFloat(wei)).to.be.closeTo(expectedPrice, 0.5)
        expect(parseFloat(wei)).to.be.closeTo(420, 1)
    })

    it('has price=150 at t=8 for zero DSF balance account', async () => {
        await increaseTime(expiration + 8 * 3600)
        const price = await token.auctionPrice({ from: zeroDSFBalance })
        const wei = fromWei(price)
        expect(parseFloat(wei)).to.be.closeTo(0.015, 0.0005)
    })

    it('accounts for DSF token settlement edge at t=8', async () => {
        const price = await token.auctionPrice()
        const wei = fromWei(price)
        // a reiteration of the price calculation formula from the contract
        const expectedPrice = 0.97 * 12 / (100 * 8) + 0.03 / 100
        expect(parseFloat(wei)).to.be.closeTo(expectedPrice, 1)
    })

    it('can be bought at t=8 by non-DSF token holder for $150', async () => {
        const balanceWas = await usd.balanceOf(auctionParticipant.address)
        await auctionParticipant.settlePut(token.address, { value: toWei('0.1') })
        const balanceIs = await usd.balanceOf(auctionParticipant.address)
        expect(parseFloat(fromWei(balanceIs.sub(balanceWas)))).to.be.closeTo(0.1 * 66.67, 0.05)
    })

    it('can be bought at t=8 by DSF token holder for $148.50', async () => {
        const block = await web3.eth.getBlock(await web3.eth.getBlockNumber())
        await dsfToken.approve(auctionParticipant.address, await dsfToken.balanceOf(accounts[0]))
        const balanceWas = await usd.balanceOf(auctionParticipant.address)
        await auctionParticipant.settlePut(token.address, { value: toWei('0.1') })
        const balanceIs = await usd.balanceOf(auctionParticipant.address)
        const usdBalanceDiff = fromWei(balanceIs.sub(balanceWas))
        const settled = fromWei(await token.settled());
        const written = fromWei(await token.written());
        expect(settled).to.eq('0.2')
        expect(written).to.eq('1')

        const elapsed = block.timestamp - expiration
        const expectedUSD = 0.1 / (0.97 * 43200 / (elapsed * 100) + 0.03 / 100)
        expect(parseFloat(usdBalanceDiff)).to.be.closeTo(expectedUSD, 0.02)
    })

    it('will reject settlement of more than the available number of contracts', async () => {
        let txFailed = false
        try {
            await auctionParticipant.settlePut(token.address, toWei('0.800000000000000001'))
        } catch (e) {
            txFailed = true
        }
        expect(txFailed).to.eq(true)
    })

    it('will fail settlement if the settlement period has ended', async () => {
        increaseTime(expiration + 3600 * 12 + 1)

        let txFailed = false
        try {
            await auctionParticipant.settlePut(token.address, toWei('0.2'), { value: toWei('0.2') })
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
        expect(parseFloat(diff)).to.be.closeTo(1000006.6, 0.01)
    })

    it('will transfer writer settlement to writer', async () => {
        const usdBalanceWas = await usd.balanceOf(writer)
        const ethBalanceWas = await web3.eth.getBalance(writer)
        const result = await token.assignment({ from: writer })
        console.log('gas used for writers #assignment:', result.receipt.gasUsed)
        const usdBalanceIs = await usd.balanceOf(writer)
        const ethBalanceIs = await web3.eth.getBalance(writer)
        const tx = await web3.eth.getTransaction(result.tx)
        expect(parseInt(ethBalanceIs - ethBalanceWas) + result.receipt.gasUsed * tx.gasPrice).to.eq(200000000000000000)
        expect(fromWei(usdBalanceIs.sub(usdBalanceWas))).to.eq('80')
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