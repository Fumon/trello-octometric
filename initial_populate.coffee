trello = require 'node-trello'
util = require 'util'
Promise = require "bluebird"

t = new trello "appkey", "usertoken"

# Trello resolver 
tresolve = (held, resolve, reject) ->
  return (err, data) ->
    if err
      reject err
    else
      resolve {data: data, extra: held}
        

gettrello = (held, args...) ->
  return new Promise (resolve,reject) ->
    args.push tresolve(held, resolve, reject)
    t.get args...


# Get a count of all cards ever in board
allcards = gettrello {}, "/1/boards/targetboard/cards",
    filter: "all"
    format: "list"
    memberCreator: "false"
    actions: "updateCard:closed,createCard"
    fields: "closed,idList,name"
    limit: 10

allcards.then((val) ->
  #console.log action.data.card for action in val
  #gettrello val.data[0], "/1/cards/#{ val.data[0].id }/actions",
  #  filter: "all"
  #).then((val)->
  #  console.log (util.inspect val, {depth: null})
  #)
  console.log (util.inspect val, {depth: null, colors: true})
  )
