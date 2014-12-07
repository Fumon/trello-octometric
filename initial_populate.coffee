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
        

# Trello api call returning promise
gettrello = (held, args...) ->
  return new Promise (resolve,reject) ->
    args.push tresolve(held, resolve, reject)
    t.get args...

# Launch an API call with a "before" date
# If launched without a date, will receive the latest cards
getCardsBefore = (date) ->
  console.log "Requesting cards before: " + date
  filterParams =
    filter: "all"
    format: "list"
    actions: "updateCard:closed,createCard"
    fields: "closed,idList,name,dateLastActivity",
    limit: 5

  filterParams.before = date.toISOString() if date?

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
        handleError = (err) ->

        # Grab the creation date
        creation_date = null
        creation_date = action.date for action in card.actions when action.type == 'createCard'

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
          success new Date(card.dateLastActivity)

# Recurse for optional depth iterations
recurseCards = (cards, depth) ->
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
    ).then((val) ->
      new Promise (resolve, reject) ->
        Promise.all(val).then((success) ->
          console.log "Successes: " +  success.length
          success.sort (a, b) ->
            # Reverse sort to find oldest
            a - b
          resolve(success[0])
        , (fail) ->
          reject(fail)
        )
    ).then((val) ->
        depth -= 1
        if depth == 0
          pg.end()
          return
        recurseCards getCardsBefore(val), depth
      , (err) ->
        console.log "Promise returns bad"
    )


# Main

# Launch a call
recurseCards getCardsBefore(new Date()), 3
