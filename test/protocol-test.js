const Protocol = artifacts.require('DSFProtocol')
const ERC20 = artifacts.require('ERC20')
const moment = require('moment')
const { toEth } = require('./utils')

let expiration = moment().add(3, 'weeks')
const strike = toEth('300')
const call = 0, put = 1

contract.only('Protocol', accounts => {
    let protocol
    let optionToken

    before(() => {
        return Protocol.deployed()
        .then(p => protocol = p)
    })

    it('creates an option token', () => {
        return protocol.issue('JUL 4 300-CALL', '7/4 300-C', expiration.unix(), call, strike)
        .then(result => {
            const { logs } = result

            expect(logs[0].event).to.eq('OptionTokenCreated')
            const { token } = logs[0].args
            console.log('created option token:', token)
            return ERC20.at(token)
        })
        .then(t => {
            optionToken = t
        })
    })

    it('opens option tokens', () => {
        return protocol.open(optionToken.address, toEth('1'), {
            value: toEth('1')
        })
        .then(() => {
            return optionToken.balanceOf(accounts[0])
        })
        .then(balance => {
            expect(balance.toString()).to.eq(toEth('1'))
        })
    })

    it('closes option tokens', () => {
        return protocol.close(optionToken.address, toEth('1'))
        .then(() => {
            return optionToken.balanceOf(accounts[0])
        })
        .then(balance => {
            expect(balance.toString()).to.eq('0')
        })
    })
})