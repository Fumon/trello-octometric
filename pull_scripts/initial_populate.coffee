trello = require 'node-trello'
util = require 'util'
pg = require 'pg'
Promise = require 'bluebird'

# Types of card creation events
createEvents = ['createCard', 'convertToCardFromCheckItem', 'copyCard', 'moveCardToBoard']

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
  # TODO: Ugly, need to redo
  t = new trello process.env['appkey'], process.env['usertoken']
  return new Promise (resolve,reject) ->
    args.push tresolve(held, resolve, reject)
    t.get args...

# Launch an API call with a "before" date
# If launched without a date, will receive the latest cards
getCards = (held, before, since) ->
  console.log "[+] Requesting 1000 cards before: #{before}"
  filterParams =
    filter: "all"
    format: "list"
    actions: "updateCard:closed,createCard,copyCard,convertToCardFromCheckItem,moveCardToBoard"
    fields: "closed,idList,name,dateLastActivity",
    limit: 1000 # TODO: Make this into settable property

  filterParams.before = before.toISOString()
  filterParams.since = since.toISOString() if since?

  # Return gettrello promise
  gettrello held, "/1/boards/#{process.env['targetboard']}/cards", filterParams


# Insert a card into the database
insertCard = (card) ->
  (success, error) ->
    # Database connection
    pg.connect process.env['pgConnectString'],
      (err, client, done) ->
        dates = []
        # Grab the creation date
        creation_date = null
        creation_date = action.date for action in card.actions when action.type in createEvents
        dates.push new Date(creation_date)

        # If the card is closed, find the date and whether it was in 'rightnow'
        closed_date = null
        finished = false
        if card.closed
          # We filtered for only closed updateCard so no need to check more
          f = action for action in card.actions when action.type == 'updateCard'
          action = f
          try
            if card.idList in process.env['donelists']
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
      Promise.resolve {list: return_list, extra: val.extra}
    , (err) ->
      # Got an error from Trello call
      Promise.reject(err)
    ).then (val) ->
        Promise.all(val.list).then((success) ->
          if success.length <= 0
            console.log "[i] (#{val.extra.iteration})\t Returned 0 new cards"
            pg.end()
            return
          success.sort sortOldest
          console.log "[=] (#{val.extra.iteration})\t#{val.extra.time}-#{success[0]} #{success.length} cards"
          # Calculate a sane time interval just in case. 
          tdiff = Math.floor((val.extra.time - success[0]) * (1/3))
          newtime = new Date(success[0].getTime() + tdiff)
          processCards(getCards {time: newtime, iteration: (val.extra.iteration + 1)}, newtime)
        , (fail) ->
          console.error fail
        )
    

    

# Main
figaro = require('figaro').parse null, () ->
  now = new Date()
  processCards(getCards {time: now, iteration: 0}, now)
