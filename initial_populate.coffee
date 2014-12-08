trello = require 'node-trello'
util = require 'util'
pg = require 'pg'
Promise = require "bluebird"

# Some constant data

rightnow = 'donelist'

t = new trello "appkey", "usertoken"

# Sort dates in reverse (oldest first)
sortOldest = (a, b) ->
  a - b

# Trello resolver 
tresolve = (held, resolve, reject) ->
  return (err, data) ->
    if err
      reject err
    else
      resolve {data: data, extra: held}
        

# Trello api call returning promise
gettrello = (held, args...) ->
  return new Promise (resolve,reject) ->
    args.push tresolve(held, resolve, reject)
    t.get args...

# Launch an API call with a "before" date
# If launched without a date, will receive the latest cards
getCards = (before, since) ->
  console.log "[+] Requesting cards " + before + " - " + since
  filterParams =
    filter: "all"
    format: "list"
    actions: "updateCard:closed,createCard,copyCard,convertToCardFromCheckItem,moveCardToBoard"
    fields: "closed,name,dateLastActivity",
    limit: 1000

  filterParams.before = before.toISOString()
  filterParams.since = since.toISOString() if since?

  # Return gettrello promise
  gettrello {}, "/1/boards/targetboard/cards", filterParams


# Insert a card into the database
insertCard = (card) ->
  (success, error) ->
    # Database connection
    pg.connect
      user: 'postgresuser'
      database: 'database'
      host: 'localhost'
      ssl: false,
      (err, client, done) ->
        dates = []
        # Grab the creation date
        creation_date = null
        creation_date = action.date for action in card.actions when action.type == 'createCard' || action.type == 'convertToCardFromCheckItem' || action.type == 'copyCard' || action.type == 'moveCardToBoard'
        dates.push new Date(creation_date)

        # If the card is closed, find the date and whether it was in 'rightnow'
        closed_date = null
        finished = false
        if card.closed
          # We filtered for only closed updateCard so no need to check more
          f = action for action in card.actions when action.type == 'updateCard'
          action = f
          try
            if action.data.list.id == rightnow
              finished = true
            closed_date = action.date
            dates.push new Date(closed_date)
          catch error
            console.error "Could not access data, ", error
            console.error (util.inspect card, {depth: null, color: true})

        # Insert into database
        q = client.query
            text: "SELECT trello.insert_card($1, $2, $3, $4, $5, $6)"
            name: 'cardinsert'
            values: [card.id, card.name, card.closed, finished, creation_date, closed_date]
          , (err, result) ->
            if err
              # Close connection
              done(client)
              error err
              return
            # Release the database connection
            done()
            dates.sort sortOldest
            success(dates[0])

# Recurse for optional depth iterations
processCards = (cards) ->
    # Receive results
    cards.then((val) ->
      return_list = []
      for card in val.data
        do (card) ->
          return_list.push new Promise insertCard(card)
      # Return a list of promises
      return_list
    , (err) ->
      # Got an error from Trello call
      throw err
    )
    

# Main

# Generate date ranges
now = new Date()
date = now.getDate()
dates = [0..100].map (c) ->
  b = new Date(now.getTime())
  b.setDate(date - c)
  s = new Date(now.getTime())
  s.setDate(date - (c + 1))
  [b, s]


requests = []
for d, i in dates
  do (d, i) ->
    requests.push(processCards(getCards(d[0], d[1])).then (val) ->
        new Promise (resolve, reject) ->
          Promise.all(val).then((success) ->
            console.log "[=] (" + i + ") " + d[0] + " - " + d[1] + ":\t" + success.length + " cards"
            success.sort sortOldest
            resolve(success[0])
          , (fail) ->
            reject(fail)
          )
    )

Promise.all(requests).then () ->
  console.log "End"
  pg.end()
, (err) ->
  console.error err
