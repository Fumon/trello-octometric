trello = require 'node-trello' 
Promise = require "bluebird" 

t = new trello "appkey", "usertoken" 

# Trello resolver 
tresolve = (resolve, reject) ->
  return (err, data) ->
    if err then reject(err) else resolve(data)

gettrello = (args...) ->
  return new Promise (resolve,reject) ->
    args.push tresolve(resolve,reject)
    t.get args...


# Get a count of all cards ever in board
allcards = gettrello "/1/boards/targetboard/actions",
    filter: "createCard"
    format: "list"
    fields: "data,date"
    memberCreator: "false"
    limit: 50

allcards.then (val) ->
  console.log val
