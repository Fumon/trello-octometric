Promise = require 'bluebird'
assert = require 'assert'

describe 'Time', () ->
  describe '#subtract', () ->
    it 'should be able to add time differences and get the same time', ()->
      now = new Date()
      before = new Date()
      before.setTime 0,0,0,0

      tdiff = now - before
      assert new Date(before.getTime() + tdiff).getTime() == now.getTime()
    


