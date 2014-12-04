trello = require 'node-trello'
util = require 'util'
pg = require 'pg'
Promise = require "bluebird"

# Some constant data

rightnow = 'donelist'

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


allcards = gettrello {}, "/1/boards/targetboard/cards",
    filter: "all"
    format: "list"
    actions: "updateCard:closed,createCard"
    fields: "closed,idList,name"
    limit: 100

allcards.then (val) ->
  for card in val.data
    do (card) ->
      # Database connection
      pg.connect
        user: 'postgresuser'
        database: 'database'
        host: 'localhost'
        ssl: false,
        (err, client, done) ->
          handleError = (err) ->
            done(client)
            console.error 'Problem executing query, ', err
            true

          # Grab the creation date
          creation_date = null
          creation_date = action.date for action in card.actions when action.type == 'createCard'

          # If the card is closed, find the date and whether it was in 'rightnow'
          closed_date = null
          finished = false
          if card.closed
            # We filtered for only closed updateCard so no need to check more
            f = action for action in card.actions when action.type == 'updateCard'
            action = f[0]
            try
              if action.data.list.id == rightnow
                finished = true
              closed_date = action.date
            catch error
              console.error "Could not access data, ", error
              console.error (util.inspect card, {depth: null, color: true})

          # Insert into database
          q = client.query
            text: "INSERT INTO trello.cards (webid, name, closed, finished, creation_date, closed_date) VALUES ($1, $2, $3, $4, $5, $6)"
            name: 'cardinsert'
            values: [card.id, card.name, card.closed, finished, creation_date, closed_date]

          q.on 'error', handleError

          q.on 'end', (end) ->
            console.log "Completed insert"
            done()
