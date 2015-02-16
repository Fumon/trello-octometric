package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	_ "github.com/lib/pq"
)

type Action struct {
	Id   string `json:"id"`
	Data struct {
		List struct {
			Id string `json:"id"`
		} `json:"list"`
		Card struct {
			Id     string `json:"id"`
			Name   string `json:"name"`
			Closed bool   `json:"closed"`
		} `json:"card"`
		Old struct {
			Closed bool `json:"closed"`
		} `json:"old"`
	} `json:"data"`
	Type string `json:"type"`
	Date string `json:"date"`
}

// Struct for processing
type WebhookAction struct {
	Action `json:"action"`
}

var finishedLists map[string]bool = map[string]bool{
	"5209128b758c3b4f2e003063": true,
	"5095d60b338f63e04a013d19": true,
}

func upsertCard(id, name, creation_date, closed_date string, closed, finished bool) error {
	db, err := sql.Open("postgres", "user=inserter dbname='quantifiedSelf' sslmode=disable")
	if err != nil {
		log.Println("Problem opening db: ", err)
		return err
	}
	defer db.Close()

	_, err = db.Query(`SELECT trello.insert_card($1, $2, $3, $4, $5, $6)`,
		id, name, closed, finished, creation_date, closed_date)
	if err != nil {
		log.Println("Problem with database upsert: ", err)
		return err
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
			err = upsertCard(wh.Action.Data.Card.Id, wh.Action.Data.Card.Name, creationDate,
				closedDate, true, finished)
			if err != nil {
				log.Println("Problem with Upsert")
			}
		}
	} else if wh.Action.Type == "createCard" {
		log.Println("Card Created")
		// Upsert Card
		err := upsertCard(wh.Action.Data.Card.Id, wh.Action.Data.Card.Name,
			wh.Action.Date, "", false, false)
		if err != nil {
			log.Println("Problem with Upsert")
		}
	}
}
