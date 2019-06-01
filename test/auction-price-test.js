const Protocol = artifacts.require('DSFProtocol')
const { expect } = require('chai')

contract('DSFProtocol', () => {

    const strike100 = '100000000000000000000'
    const discount95 = '950000000000000000'
    const noDiscount = '1000000000000000000'

    describe('auction pricing', () => {
        let protocol
        before(() => {
            Protocol.deployed()
            .then(p => protocol = p)
        })
        it('calculates put option price at t=0', () => {
            const elapsed = 0

            return protocol.putAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            .then(price => {
                expect(price.toString()).to.eq('0')
                return protocol.putAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('0')
            })
        })

        it('calculates put option price at t=6h', () => {
            const elapsed = 6 * 3600

            return Protocol.deployed()
            .then(protocol => {
                return protocol.putAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            })
            .then(price => {
                expect(price.toString()).to.eql('50000000000000000000')
                return protocol.putAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('52631578947368421052')
            })
        })

        it('calculates put option price at t=12h', () => {
            const elapsed = 12 * 3600

            return Protocol.deployed()
            .then(protocol => {
                return protocol.putAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            })
            .then(price => {
                expect(price.toString()).to.eql('100000000000000000000')
                return protocol.putAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('100000000000000000000')
            })
        })

        it('calculates call option price at t=0', () => {
            const elapsed = 1
            return Protocol.deployed()
            .then(protocol => {
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            })
            .then(price => {
                expect(price.toString()).to.eq('4320000000000000000000000')
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('4104000000000000000000000')
            })
        })

        it('calculates call option price at t=6h', () => {
            const elapsed = 6 * 3600

            return Protocol.deployed()
            .then(protocol => {
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            })
            .then(price => {
                expect(price.toString()).to.eq('200000000000000000000')
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('190000000000000000000')
            })
        })

        it('calculates call option price at t=12h', () => {
            const elapsed = 12 * 3600
            return Protocol.deployed()
            .then(protocol => {
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, noDiscount)
            })
            .then(price => {
                expect(price.toString()).to.eq(strike100)
                return protocol.callAuctionUSDPrice.call(strike100, elapsed, discount95)
            })
            .then(price => {
                expect(price.toString()).to.eq('100000000000000000000')
            })
        })
    })
})