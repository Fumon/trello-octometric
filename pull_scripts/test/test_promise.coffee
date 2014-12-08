Promise = require 'bluebird'
assert = require 'assert'

describe 'Promise', () ->
  describe '#then((v){return promise}).then', () ->
    it 'should trigger success on resolve', (done) ->
      v = new Promise (resolve, reject) ->
        resolve()
      v.then((val) ->
        new Promise (resolve, reject) ->
          resolve()
      ).then((val) ->
        done()
      , (err) ->
        done(Error("Fail"))
      )
    it 'should trigger error on reject', (done) ->
      v = new Promise (resolve, reject) ->
        resolve()
      v.then((val) ->
        new Promise (resolve, reject) ->
          reject()
      ).then((val) ->
        done(Error("Fail"))
      , (err) ->
        done()
      )
  describe '#then(() -> all(v).then(func, func)).then', () ->
    it 'should trigger success in final then on resolve', (done) ->
      g = new Promise (resolve, reject) ->
        resolve()
      g.then((val) ->
        v = []
        for n in [10..1]
          do (n) ->
            v.push new Promise (resolve, reject) ->
              resolve()
        v
      ).then((val) ->
        new Promise (resolve, reject) ->
          Promise.all(val).then () ->
            resolve()
          , () ->
            reject()
      ).then((val) ->
        done()
      , (err) ->
        done(Error("fail"))
      )
    it 'should trigger fail in final then on reject', (done) ->
      g = new Promise (resolve, reject) ->
        resolve()
      g.then((val) ->
        v = []
        for n in [10..1]
          do (n) ->
            v.push new Promise (resolve, reject) ->
              if n == 3
                reject()
              else
                resolve()
        v
      ).then((val) ->
        new Promise (resolve, reject) ->
          Promise.all(val).then () ->
            resolve()
          , () ->
            reject()
      ).then((val) ->
        done(Error("fail"))
      , (err) ->
        done()
      )


