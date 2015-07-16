package main

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
)

func insertListCard(db *sql.DB, id, name, creation_date string) error {
	var err error
	_, err = db.Exec(`SELECT trello.insert_list_card($1, $2, $3)`,
		id, name, creation_date)
	if err != nil {
		log.Println("Problem with database insert list card: ", err)
		return err
	}
	return nil
}

func removeListCard(db *sql.DB, id, closed_date string) error {
	var err error
	_, err = db.Exec(`SELECT trello.remove_list_card($1, $2)`,
		id, closed_date)
	if err != nil {
		log.Println("Problem with database remove list card: ", err)
		return err
	}
	return nil
}

func queryCard(cardid, actionfilter, apikey, token string) ([]byte, error) {
	queryString := fmt.Sprintf(
		"https://trello.com/1/cards/%v?fields=closed,actions,id,idList,idBoard&actions=%v&key=%v&token=%v",
		cardid, actionfilter,
		apikey, token,
	)
	resp, err := http.Get(queryString)
	if err != nil {
		log.Println("Problem requesting trello cards: ", err)
		return nil, err
	}

	r, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()

	return r, nil
}

func queryListCards(listid, apikey, token string) ([]byte, error) {
	queryString := fmt.Sprintf(
		"https://trello.com/1/lists/%v/cards?filter=open&key=%v&token=%v",
		listid,
		apikey, token,
	)
	resp, err := http.Get(queryString)
	if err != nil {
		log.Println("Problem requesting trello cards: ", err)
		return nil, err
	}

	r, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()

	return r, nil
}

func queryBoard(boardid, actionfilter, apikey, token string) ([]byte, error) {
	queryString := fmt.Sprintf(
		"https://trello.com/1/boards/%v/actions?filter=%v&key=%v&token=%v",
		boardid, actionfilter,
		apikey, token,
	)
	resp, err := http.Get(queryString)
	if err != nil {
		log.Println("Problem requesting trello cards: ", err)
		return nil, err
	}

	r, _ := ioutil.ReadAll(resp.Body)
	resp.Body.Close()

	return r, nil
}

func testListEventIncoming(act Action) bool {
	if (act.Type == "updateList" &&
		act.Data.List.Closed == false &&
		act.Data.Old.Closed == true) ||
		act.Type == "moveListToBoard" {

		return true
	}
	return false
}

func testListEventOutgoing(act Action) bool {
	if (act.Type == "updateList" &&
		act.Data.List.Closed == true &&
		act.Data.Old.Closed == false) ||
		act.Type == "moveListFromBoard" {

		return true
	}
	return false
}
