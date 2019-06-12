const Protocol = artifacts.require('DSFProtocol')
const USDMock = artifacts.require('USDMock')
const ERC20 = artifacts.require('ERC20')

const moment = require('moment')
const { expect } = require('chai')
const _ = require('lodash')

const utils = require('./utils')
const { asFixed } = utils

const expiration = moment().add(1, 'day')
const strike = web3.utils.toWei('100')

let call = {
    expiration: expiration.unix(),
    flavor: 0,
    strike
}, put = {
    expiration: expiration.unix(),
    flavor: 1,
    strike
}

const txOpts = {
    gas: 500000,
    gasPrice: 0
}

let snapshot

let brian, chris

let protocol, usdMock

const MAX_DISCOUNT = 0.950583588746887319
const AUCTION_DURATION = 12 * 3600
const TEST_STRIKE_PRICE = web3.utils.fromWei(strike)

contract.only('DSFProtocol', accounts => {

    [brian, chris] = accounts

    before(() => {
        console.log('snapshot the test chain')
        return utils.snapshot()
        .then(_id => {
            console.log('get deployed contracts')
            snapshot = _id
            return Promise.all([
                Protocol.deployed(),
                USDMock.deployed()
            ])
        })
        .then(contracts => {
            [protocol, usdMock] = contracts
        })
    })

    after(() => {
        console.log('cleaning up!')
        return utils.revert(snapshot)
    })

    before(() => {
        console.log('seed accounts with test USD')
        return Promise.all([
            _.map(accounts, (addr) => {
                return usdMock.mint(addr, web3.utils.toWei('10000'), { from: addr })
            })
        ])
        .then(() => {
            console.log('approve protocol for USD from all accounts')
            return Promise.all([
                _.map(accounts, addr => {
                    return usdMock.approve(protocol.address, web3.utils.toWei('10000'), { from: addr })
                })
            ])
        })
        // .then(() => {
        //     return protocol.mintProtocolToken(brian, web3.utils.toWei('10000'), { from: brian, gas: 250000 })
        // })
        .then(() => {
            console.log('issue put and call option tokens')
            return Promise.all([
                protocol.issue('CALL', 'CALL', call.expiration, call.flavor, call.strike),
                protocol.issue('PUT',  'PUT',  put.expiration,  put.flavor,  put.strike),
            ])
        })
        .then(result => {
            call.address = result[0].logs[0].args.token
            call.token = ERC20.at(call.address)
            put.address = result[1].logs[0].args.token
            put.token = ERC20.at(put.address)
        })
    })

    before(() => {
        console.log('open puts and calls')
        return Promise.all([
            protocol.open(call.address, web3.utils.toWei('2'), { from: brian, value: web3.utils.toWei('2'), gas: 250000 }),
            protocol.open(put.address, web3.utils.toWei('2'), { from: chris, gas: 250000 })
        ])
    })

    describe('timePreference', () => {
        it('applies a time preference to token holders', () => {
            return Promise.all([
                protocol.preference(brian),
                protocol.preference(chris)
            ])
            .mapWei(values => {
                expect(values).to.eql([
                    '1',
                    '0'
                ])
                return Promise.all([
                    protocol.discount(brian),
                    protocol.discount(chris)
                ])
            })
            .mapWei(values => {
                expect(values).to.eql([
                    '0.950583588746887319',
                    '1'
                ])
            })
        })
    })

    const TIME_PREF = 1798

    describe('auction', () => {
        describe('at the beginning', () => {

            before(() => {
                return utils.getBlock()
                .then(block => {
                    const timeTillExpiration = call.expiration - block.timestamp
                    let i = timeTillExpiration + 1
                    return utils.timeTravel(i)
                })
            })

            it('call starts at price ~ Infinity', () => {
                return bid(call.address, 1, false, chris)
                .then(effects => {
                    const ONE_WEI = web3.utils.fromWei('1')
                    // auction bids on 1 wei worth of ETH
                    expectEthEq(effects.ethChange, ONE_WEI)

                    // auction receives ETH at expected price
                    const expectedUSDChange = '-0.00000000000432'
                    expectEthEq(effects.usdChange, expectedUSDChange)
                })
            })

            it('discounts DSF token holder start price', () => {
                return bid(call.address, 1, false, brian)
                .then(effects => {
                    const ONE_WEI = web3.utils.fromWei('1')
                    // auction bids on 1 wei worth of ETH
                    expectEthEq(effects.ethChange, ONE_WEI)

                    // auction receives ETH at expected price
                    const expectedUSDChange = '-0.000000000004106521'
                    expectEthEq(effects.usdChange, expectedUSDChange)
                })
            })

            it('call starts at price ~ Infinity', () => {
                let usdWas, ethWas, paid
                return _balances(brian)
                .then(balances => {
                    [ethWas, usdWas] = balances
                    return protocol.bid(call.address, 1, { from: brian, gas: 500000, gasPrice: 0 })
                })
                .then(result => {
                    tx = result.receipt
                    return _balances(brian)
                })
                .then(balances => {
                    const [ethIs, usdIs] = balances
                    return utils.getBlock()
                    .then(block => {
                        const { timestamp } = block
                        const elapsed = timestamp - call.expiration
                        const expectedPrice = MAX_DISCOUNT * AUCTION_DURATION * web3.utils.fromWei(call.strike) / elapsed
                        let actualPrice = usdWas.sub(usdIs) - 0
                        expect(actualPrice).to.closeTo(expectedPrice - 0, 10)
                        paid = usdWas.sub(usdIs) - 0

                        expect(ethIs.sub(ethWas) - 0).to.eq(1)
                    })
                })
                .then(() => {
                    return protocol.holdersSettlement(call.address)
                })
                .then(settlement => {
                    expect(settlement - 0).to.eq(paid - web3.utils.fromWei(call.strike))
                })
            })

            /**
             * Tests that when the auction initially begins
             * the bid for the protocol to buy ETH (Put option)
             * is effectively zero
             */
            it('put starts at price = Infinity', () => {
                let ethWas, usdWas, proceeds
                return _balances(brian)
                .then(balances => {
                    [ethWas, usdWas] = balances
                    return protocol.bid(
                        put.address,
                        web3.utils.toWei('1'), {
                            from: brian,
                            value: web3.utils.toWei('1'),
                            ...txOpts
                        }
                    )
                })
                .then(() => {
                    return _balances(brian)
                })
                .then(balances => {
                    console.debug(balances)
                    let [ethIs, usdIs] = balances

                    return utils.getBlock()
                    .then(block => {
                        let elapsed = block.timestamp - put.expiration
                        // calculate the bid price USD ~$0.00
                        const bidPriceUSD = elapsed * TEST_STRIKE_PRICE / AUCTION_DURATION
                        const bidPriceWithDiscount = bidPriceUSD / MAX_DISCOUNT
                        expect(ethWas.sub(ethIs) - 0).to.eq(web3.utils.toWei('1') - 0)
                        proceeds = web3.utils.fromWei(usdIs.sub(usdWas))
                        expect(proceeds - 0).to.be.closeTo(bidPriceWithDiscount, 0.00231)
                        return protocol.holdersSettlement(put.address)
                    })
                })
                .then(value => {
                    const expectedSettlement = TEST_STRIKE_PRICE - proceeds
                    expect(web3.utils.fromWei(value) - 0).to.be.closeTo(expectedSettlement, 0.001)
                    return protocol.openInterest(put.address)
                })
                .then(interest => {
                    expect(interest.toString()).to.eq(web3.utils.toWei('1'))
                })
            })
        })

        describe('middle auction', () => {
            before(() => {
                return utils.getBlock()
                .then(block => {
                    let i = call.expiration.toPrecision() - block.timestamp
                    return utils.timeTravel(i)
                })
            })

            it('is priced correctly at t = 0.5', () => {
                let usdWas, ethWas, tx, paid
                return _balances(brian)
                .then(balances => {
                    [ethWas, usdWas] = balances

                    return protocol.bid(call.address, web3.utils.toWei('1'), { from: brian, gas: 500000 })
                })
                .receipt(_tx => {
                    tx = _tx
                    return _balances(brian)
                })
                .then(balances => {
                    const [ethIs, usdIs] = balances
                    return utils.getBlock()
                    .then(block => {
                        let elapsed = block.timestamp + TIME_PREF - (call.expiration - 43200)
                        let expectedPrice = (86400 * 200) / elapsed;

                        let actualPrice = usdWas.sub(usdIs) - 0
                        expect(actualPrice / 1e18).to.be.closeTo(expectedPrice, 1)
                        paid = usdWas.sub(usdIs)

                        expect(actualPrice / 1e18).to.be.closeTo(expectedPrice, 1)
                        debugger
                        expect(ethIs.sub(ethWas).add(tx.gasUsed) - 0).to.eq(web3.toWei(1) - 0)
                    })
                })
                // .then(() => {
                //     return protocol.holdersSettlement(call.address)
                // })
                // .then(settlement => {
                //     expect(settlement / 1e18)
                //     .be.closeTo(paid.sub(web3.toWei(web3.toBigNumber(200)))
                //     .add(6238 - 200) - 0)
                // })
            })

            it('put sells at correct price', () => {
                let ethWas, usdWas, tx, proceeds
                return _balances(brian)
                .then(balances => {
                    [ethWas, usdWas] = balances
                    return protocol.bid(put.address, web3.utils.toWei('1'), { from: brian, value: web3.toWei(1), gas: 500000 })
                })
                .receipt(_tx => {
                    tx = _tx
                    return _balances(brian)
                })
                .then(balances => {
                    return utils.getBlock()
                    .then(block => {
                        let [ethIs, usdIs] = balances
                        let elapsed = block.timestamp + TIME_PREF - (put.expiration - 43200)
                        let expectedProceeds = 1 / (86400 / (elapsed * 200));

                        expect(ethWas.sub(ethIs).sub(tx.gasUsed).toPrecision()).to.eql(web3.toWei(1))

                        proceeds = usdIs.sub(usdWas)
                        expect(proceeds / 1e18).to.be.closeTo(expectedProceeds, 0.01)
                    })
                })
                .then(() => {
                    return protocol.openInterest(put.address)
                })
                .then(interest => {
                    expect(interest.toPrecision()).to.eq('0')
                })
            })
        })
    })

    describe('resolving settlement', () => {
        before(() => {
            // travel to after the contracts are expired by evm_increaseTime
            return utils.timeTravel(43201)
        })

        it('settles the call token holders correctly', () => {
            let ethWas, usdWas, settlement

            return protocol.holdersSettlement(call.address)
            .then(_settlement => {
                settlement = _settlement
                return _balances(brian)
            })
            .then(balances => {
                [ethWas, usdWas] = balances

                return protocol.settle(call.address, { from: brian, gas: 250000 })
            })
            .then(() => {
                return Promise.all([
                    call.token.balanceOf(brian),
                    call.token.totalSupply(),
                    _balances(brian)
                ])
            })
            .then(results => {
                let [balance, supply] = results
                let [ethIs, usdIs] = results[2]
                expect(balance.toPrecision()).to.eq('0')
                expect(supply.toPrecision()).to.eq('0')
                expect(usdIs.sub(usdWas).toPrecision()).to.eq(settlement.toPrecision())
            })
        })

        it('settles the put token holders correctly', () => {
            let ethWas, usdWas, settlement

            return protocol.holdersSettlement(put.address)
            .then(_settlement => {
                settlement = _settlement
                return _balances(chris)
            })
            .then(balances => {
                [ethWas, usdWas] = balances

                return protocol.settle(put.address, { from: chris, gas: 250000 })
            })
            .then(() => {
                return Promise.all([
                    call.token.balanceOf(chris),
                    call.token.totalSupply(),
                    _balances(chris)
                ])
            })
            .then(results => {
                let [balance, supply] = results
                let [ethIs, usdIs] = results[2]
                expect(balance.toPrecision()).to.eq('0')
                expect(supply.toPrecision()).to.eq('0')
                expect(usdIs.sub(usdWas).toPrecision()).to.eq(settlement.toPrecision())
            })
        })
    })
})

function expectEthEq(a, b) {
    expect(asFixed(a)).to.eq(asFixed(b))
}

function calculateExpectedPrice(strike, expiration, timestamp, isPut) {
    const elapsed = timestamp - expiration
    if (isPut) {
        return duration * elapsed / strike
    } else {
        return strike * AUCTION_DURATION / elapsed
    }
}

function bid(token, amount, isPut, fromAccount) {
    let block, ethWas, usdWas, ethIs, usdIs,
        usdChange, ethChange,
        holdersSettlement

    return _balances(fromAccount)
    .then(balances => {
        [ethWas, usdWas] = balances

        return protocol.bid(token, amount, {
            from: fromAccount,
            value: isPut ? amount : 0,
            ...txOpts
        })
    })
    .then(result => {
        return utils.getBlock(result.receipt.blockNumber)
    })
    .then(b => {
        block = b
        return _balances(fromAccount)
    })
    .then(balances => {
        [ethIs, usdIs] = balances
        usdChange = usdIs.sub(usdWas)
        ethChange = ethIs.sub(ethWas)
        return protocol.holdersSettlement(token)
    })
    .then(settlement => {
        holdersSettlement = web3.utils.fromWei(settlement)
        return {
            block,
            usdChange,
            ethChange,
            holdersSettlement
        }
    })
}

function _balances(address) {
    return Promise.all([
        utils.getBalance(address),
        usdMock.balanceOf(address)
    ])
}