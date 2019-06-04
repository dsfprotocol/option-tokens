'use strict'

const _ = require('lodash')

module.exports.toEth = function(str) {
    return str + '000000000000000000'
}

Promise.prototype.receipt = function(next) {
    return this.then(tx => {
        return new Promise((resolve, reject) => {
            web3.eth.getTransactionReceipt(tx, (err, data) => {
                if (err)
                    reject(err)
                else
                    resolve( next(data) )
            })
        })
    })
}

Promise.prototype.mapWei = function(next) {
    return this.then(values => {
        let eth = _.map(values, value => {
            return web3.fromWei(value).toPrecision()
        })

        return next(eth)
    })
}

module.exports.timeTravel = function(time) {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time],
            id: new Date().getTime()
        }, (err, data) => {
            if (err)
                return reject(err)

            web3.currentProvider.send({
                jsonrpc: '2.0',
                method: 'evm_mine',
                params: [],
                id: new Date().getSeconds()
            }, () => {
                resolve(data)
            })
        })
    })
}

module.exports.snapshot = function() {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_snapshot",
            params: [],
            id: new Date().getTime()
        }, (err, data) => {
            if (err)
                return reject(err)
            resolve(data)
        })
    })
}

module.exports.revert = function(id) {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_revert",
            params: [id],
            id: new Date().getTime()
        }, (err, data) => {
            if (err)
                return reject(err)
            resolve(data)
        })
    })
}

module.exports.getBlock = function() {
    return new Promise((resolve, reject) => {
        web3.eth.getBlockNumber((err, data) => {
            web3.eth.getBlock(data, (err, data) => {
                resolve(data)
            })
        })
    })
}

module.exports.getBalance = function(address) {
    return new Promise((resolve, reject) => {
        web3.eth.getBalance(address, (err, data) => {
            resolve(data)
        })
    })
}