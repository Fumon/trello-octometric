package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strconv"
	"time"

	_ "github.com/lib/pq"
)

// TODO: Put this in a config file
var finishedLists map[string]bool = map[string]bool{
	"5209128b758c3b4f2e003063": true,
	"5095d60b338f63e04a013d19": true,
}

var createEvents map[string]bool = map[string]bool{
	"createCard":                 true,
	"convertToCardFromCheckItem": true,
	"copyCard":                   true,
	"moveCardToBoard":            true,
}

func openDb(user string) (*sql.DB, error) {
	db, err := sql.Open("postgres", fmt.Sprintf("user=%v dbname='quantifiedSelf' sslmode=disable", user))
	if err != nil {
		log.Println("Problem opening db: ", err)
		return nil, err
	}
	return db, nil
}

func upsertCard(db *sql.DB, id, name, creation_date, closed_date string, closed, finished bool) error {
	var err error
	if closed_date == "" {
		_, err = db.Query(`SELECT trello.insert_card($1, $2, $3, $4, $5, $6)`,
			id, name, closed, finished, creation_date, nil)
	} else {
		_, err = db.Query(`SELECT trello.insert_card($1, $2, $3, $4, $5, $6)`,
			id, name, closed, finished, creation_date, closed_date)
	}
	if err != nil {
		log.Println("Problem with database upsert: ", err)
		return err
	}
	return nil
}

func catchUp(board, apikey, token string) error {
	db, err := openDb("appread")
	if err != nil {
		return err
	}
	defer db.Close()

	// Find the last entry in the dailytalies table
	var dateepoch string
	err = db.QueryRow(
		`SELECT EXTRACT(epoch FROM day)::int as time FROM trello.dailytallies ORDER BY day DESC LIMIT 1`,
	).Scan(&dateepoch)
	if err != nil {
		log.Println("Problem selecting from dailytallies: ", err)
		return err
	}

	log.Println("Dateepoch: ", dateepoch)

	epoch, err := strconv.ParseInt(dateepoch, 10, 64)
	if err != nil {
		log.Println("Could not parse epoch: ", err)
		return err
	}

	// Get all relevant card actions since the day before
	// TODO: Limit the number selected cards for batch processing
	targetDate := time.Unix(epoch, 0).Add(-24 * time.Hour)
	queryString := fmt.Sprintf(
		"https://trello.com/1/boards/%v/cards?filter=all&format=list&actions=updateCard:closed,createCard,copyCard,convertToCardFromCheckItem,moveCardToBoard&fields=closed,idList,name,dateLastActivity&limit=1000&since=%v&key=%v&token=%v",
		board, targetDate.UTC().Format(time.RFC3339), apikey, token,
	)
	resp, err := http.Get(queryString)
	if err != nil {
		log.Println("Problem requesting trello cards: ", err)
		return err
	}

	r, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()

	var bc []BoardCard
	json.Unmarshal(r, &bc)
	log.Println("Recieved ", len(bc), " cards in catchup")

	// Open DB for upsert
	ndb, err := openDb("inserter")
	if err != nil {
		return err
	}
	defer ndb.Close()

	// Upsert into db
	for _, c := range bc {
		creationDateTemp := time.Now()
		creationDate := ""
		closedDate := ""
		closed := c.Closed
		finished := false
		for _, a := range c.Actions {
			_, ok := createEvents[a.Type]
			if ok {
				// Find the earliest creation date
				t, _ := time.Parse(time.RFC3339, a.Date)
				if creationDateTemp.After(t) {
					creationDateTemp = t
					creationDate = a.Date
				}
			} else if a.Type == "updateCard" {
				// Closed
				closed = true
				closedDate = a.Date
				_, ok = finishedLists[a.Data.List.Id]
				if ok {
					finished = true
				}
			}
		}

		// Upsert
		err = upsertCard(ndb, c.Id, c.Name, creationDate, closedDate, closed, finished)
		if err != nil {
			log.Println("Problem with Upsert")
			return err
		}
	}
	return nil
}

func processAction(data []byte, apikey string, token string) {
	// Parse request into json
	var wh WebhookAction
	err := json.Unmarshal(data, &wh)
	if err != nil {
		log.Fatal("Problem umarshalling data: ", err)
	}

	if wh.Action.Id == "" {
		// Empty parse?
		log.Println("Empty parse")
		return
	}

	// Open DB for upsert
	ndb, err := openDb("inserter")
	if err != nil {
		log.Println("Error opening db for upsert")
		return
	}
	defer ndb.Close()

	if wh.Action.Type == "updateCard" {
		// Check if this is a closed event
		if wh.Action.Data.Card.Closed && !wh.Action.Data.Old.Closed {
			log.Println("Card closed")
			// In case we didn't catch the createCard event, find it from Card actions

			query := fmt.Sprintf("https://trello.com/1/cards/%v/actions?filter=createCard&key=%v&token=%v", wh.Action.Data.Card.Id, apikey, token)
			resp, err := http.Get(query)
			if err != nil {
				log.Println("Problem accessing card: ", err)
				return
			}
			defer resp.Body.Close()

			// Parse into action
			ret, _ := ioutil.ReadAll(resp.Body)
			var a []Action
			err = json.Unmarshal(ret, &a)
			if err != nil {
				log.Println("Error unmarshalling get body: ", err)
				return
			}

			// Store dates
			creationDate := a[0].Date
			closedDate := wh.Action.Date

			// Figure out if it's a finished card
			finished := false
			_, ok := finishedLists[wh.Action.Data.List.Id]
			if ok {
				log.Println("Card Finished")
				finished = true
			}

			// Upsert the card
			err = upsertCard(ndb, wh.Action.Data.Card.Id, wh.Action.Data.Card.Name, creationDate,
				closedDate, true, finished)
			if err != nil {
				log.Println("Problem with Upsert")
			}
		} else if !wh.Action.Data.Card.Closed && wh.Action.Data.Old.Closed {
			// Unarchive card
			card := wh.Action.Data.Card
			err = insertListCard(ndb, card.Id, card.Name, wh.Action.Date)
			if err != nil {
				log.Println("Problem with Upsert")
			}
		}
	} else if wh.Action.Type == "createCard" {
		log.Println("Card Created")
		// Upsert Card
		err := upsertCard(ndb, wh.Action.Data.Card.Id, wh.Action.Data.Card.Name,
			wh.Action.Date, "", false, false)
		if err != nil {
			log.Println("Problem with Upsert")
		}
	} else if wh.Action.Type == "moveCardFromBoard" || wh.Action.Type == "moveCardToBoard" {
		// Unarchive card

		closed := (wh.Action.Type == "moveCardFromBoard")
		card := wh.Action.Data.Card

		if closed {
			err = removeListCard(ndb, card.Id, wh.Action.Date)
			if err != nil {
				log.Println("Problem with Upsert")
			}
		} else {
			err = insertListCard(ndb, card.Id, card.Name, wh.Action.Date)
			if err != nil {
				log.Println("Problem with Upsert")
			}
		}
	} else if testListEventIncoming(wh.Action) || testListEventOutgoing(wh.Action) {
		// Get all cards in list

		var cards []BoardCard
		cardsstr, err := queryListCards(wh.Action.Data.List.Id, apikey, token)
		if err != nil {
			log.Fatal("JSON error, ", err)
		}

		json.Unmarshal(cardsstr, &cards)

		closed := testListEventOutgoing(wh.Action)
		for _, c := range cards {
			if closed {
				err = removeListCard(ndb, c.Id, wh.Action.Date)
				if err != nil {
					log.Println("Problem with Upsert")
				}
			} else {
				err = insertListCard(ndb, c.Id, c.Name, wh.Action.Date)
				if err != nil {
					log.Println("Problem with Upsert")
				}
			}
		}
	} else {
		debugJSON(data)
	}
}
