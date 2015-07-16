package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"sort"
	"time"
)

func debugJSON(str []byte) {
	var c interface{}
	json.Unmarshal(str, &c)
	indented, _ := json.MarshalIndent(c, "", "\t")
	log.Println(string(indented))
}

type ChangeTime struct {
	listId     string
	listBefore string
	movedAt    time.Time
}

type ChangeTimes []ChangeTime

func (c ChangeTimes) Len() int { return len(c) }

func (c ChangeTimes) Swap(i, j int) { c[j], c[i] = c[i], c[j] }

func (c ChangeTimes) Less(i, j int) bool { return c[i].movedAt.Before(c[j].movedAt) }

// Shouldn't need this unless updating from older versions or API from trello changes
// Syncs closed statuses to those directly on the board now
func syncDB(board, apikey, token string) error {
	log.Println("Syncing open cards")
	// Grab all visible cards on board from Trello
	queryString := fmt.Sprintf(
		"https://trello.com/1/boards/%v/cards?filter=visible&fields=name&limit=1000&key=%v&token=%v",
		board, apikey, token,
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
	log.Println("Recieved ", len(bc), " open cards")

	// Build map for searching
	cmap := map[string]bool{}
	for _, card := range bc {
		cmap[card.Id] = true
	}

	// Grab open cards on db
	db, err := openDb("appread")
	if err != nil {
		return err
	}
	defer db.Close()

	rows, err := db.Query(
		`SELECT did, webid FROM trello.cards WHERE closed is FALSE;`,
	)
	if err != nil {
		log.Println("Problem selecting from cards: ", err)
		return err
	}
	defer rows.Close()

	ndb, err := openDb("inserter")
	if err != nil {
		log.Fatalln("Error opening DB: ", err)
	}
	defer ndb.Close()

	// Get ListMove actions
	lmstr, err := queryBoard(
		*model,
		"moveListFromBoard",
		apikey, token,
	)
	if err != nil {
		log.Fatalln("Problem getting board actions, ", err)
	}

	// Parse
	var listMoves []Action
	json.Unmarshal(lmstr, &listMoves)

	// Get ListArchive actions
	lastr, err := queryBoard(
		*model,
		"updateList:closed",
		apikey, token,
	)
	if err != nil {
		log.Fatalln("Problem getting board actions, ", err)
	}

	// Parse
	var listArchives []Action
	json.Unmarshal(lastr, &listArchives)

	// Test each open card in db and update if not in open card list from trello
	unsynced := 0
	cardMoved := 0
	cardDeleted := 0
	closed := 0
	listArchived := 0
	listMoved := 0
	successfullyDated := 0
	//R:
	for rows.Next() {
		var did, webid string
		if err = rows.Scan(&did, &webid); err != nil {
			log.Fatalln("Problem parsing query results, ", err)
		}
		_, ok := cmap[webid]
		if !ok {
			unsynced++
			// Figure out why it's closed to recover the date
			cstr, err := queryCard(
				webid,
				//"moveCardToBoard,moveCardFromBoard,updateCard:idList",
				"all",
				apikey, token,
			)
			if err != nil {
				log.Fatal("Problem querying")
			}

			// Parse
			var card BoardCard
			json.Unmarshal(cstr, &card)

			// Determine reason
			foundTime := false
			foundFinished := false
			var closedTime time.Time
			if card.IdBoard != "" && card.IdBoard != *model {
				// Find dates
				//t, _ := time.Parse(time.RFC3339, a.Date)
				var latestCardMoveTo time.Time
				foundCardMove := false
				var listchanges []Action
				for _, a := range card.Actions {
					if a.Type == "moveCardToBoard" && a.Data.BoardSource.Id == *model {
						foundCardMove = true
						ttime, _ := time.Parse(time.RFC3339, a.Date)
						if ttime.After(latestCardMoveTo) {
							latestCardMoveTo = ttime
						}
					} else if a.Data.Old.IdList != "" { //updateCard:listId
						listchanges = append(listchanges, a)
					} else if a.Type == "createCard" {
						listchanges = append(listchanges, a)
					}
				}

				if len(listchanges) <= 1 {
					if !foundCardMove {
						// List Moved without list changes
						found := false
						var latestListMove time.Time
						for _, lm := range listMoves {
							if card.IdList == lm.Data.List.Id {
								found = true
								ttime, _ := time.Parse(time.RFC3339, lm.Date)
								if ttime.After(latestListMove) {
									latestListMove = ttime
								}
							}
						}
						if !found {
							debugJSON(cstr)
							log.Println(cstr)
							log.Fatal("Not found in move listing")
						} else {
							listMoved++
							foundTime = true
							closedTime = latestListMove
						}
					} else {
						// Card Moved
						cardMoved++
						foundTime = true
						closedTime = latestCardMoveTo
					}
				} else if len(listchanges) > 1 {
					if !foundCardMove {
						// Find list that moved
						listMoved++

						// Make a list of times that the card has moved
						// Use it to find out if it was on a list when it moved
						var listChangedTimesList ChangeTimes
						for _, lc := range listchanges {
							ttime, _ := time.Parse(time.RFC3339, lc.Date)
							if lc.Type == "createCard" {
								listChangedTimesList = append(
									listChangedTimesList,
									ChangeTime{
										listId:  lc.Data.List.Id,
										movedAt: ttime,
									},
								)
							} else {
								listChangedTimesList = append(
									listChangedTimesList,
									ChangeTime{
										listId:     lc.Data.ListAfter.Id,
										listBefore: lc.Data.ListBefore.Id,
										movedAt:    ttime,
									},
								)
							}
						}
						// Sort
						sort.Sort(listChangedTimesList)

						onListWhenMoved := false
						var latest time.Time
						for i, cht := range listChangedTimesList {
							for _, lm := range listMoves {
								movedListId := lm.Data.List.Id
								if cht.listId == movedListId || cht.listBefore == movedListId {
									ttime, _ := time.Parse(time.RFC3339, lm.Date)
									if i < (len(listChangedTimesList) - 1) {
										if ttime.Before(listChangedTimesList[i+1].movedAt) {
											onListWhenMoved = true
											latest = ttime
										}
									} else {
										onListWhenMoved = true
										latest = ttime
									}
								}
							}
						}
						if onListWhenMoved {
							foundTime = true
							closedTime = latest
						} else {
							//debugJSON(cstr)
							//log.Printf("%+v\n", listChangedTimesList)
							//debugJSON(lmstr)
							//log.Fatalln("UNEXPECTED!")
						}
					} else {
						//log.Printf("Listmoves: %+v\n", listchanges)
						debugJSON(cstr)
						log.Fatal("Moved and List changes")
					}
				}
			} else if card.IdList != "" {
				// List Archived: Find current list's close action for date

				// Search
				var latestListArchived time.Time
				found := false
				for _, la := range listArchives {
					if card.IdList == la.Data.List.Id && la.Data.List.Closed == true {
						found = true
						ttime, _ := time.Parse(time.RFC3339, la.Date)
						if ttime.After(latestListArchived) {
							latestListArchived = ttime
						}
					}
				}
				if !found && card.Closed == true {
					// Straight up, this card is closed but wasn't caught by the webhook
					closed++
					closedTimeFound := false
					var cardClosedTime time.Time
					for _, ca := range card.Actions {
						if ca.Data.Old.Closed == false {
							ttime, _ := time.Parse(time.RFC3339, ca.Date)
							if ttime.After(cardClosedTime) {
								closedTimeFound = true
								cardClosedTime = ttime
								_, ok := finishedLists[ca.Data.List.Id]
								if ok {
									foundFinished = true
								} else {
									foundFinished = false
								}
							}
						}
					}

					if closedTimeFound {
						foundTime = true
						closedTime = cardClosedTime
					}
				} else if found {
					listArchived++
					foundTime = true
					closedTime = latestListArchived
				} else {
					debugJSON(cstr)
					log.Fatal("Unexplained!")
				}
			} else {
				// Deleted... cannot recover date of deletion
				cardDeleted++
			}

			if foundTime {
				// Update
				log.Println(closedTime, ": ", foundFinished)
				successfullyDated++
				log.Println("Updating")

				result, err := ndb.Exec(
					"UPDATE trello.cards SET (closed, finished, closed_date) = ($1, $2, $3) WHERE webid = $4",
					foundTime, foundFinished, closedTime, card.Id,
				)
				if err != nil {
					log.Fatal("Error updating, ", err)
				}

				i, err := result.RowsAffected()
				if err != nil {
					log.Fatal("Error getting Rows Affected, ", err)
				}
				if i < 1 {
					log.Fatal(i, " rows affected")
				}
			}
		}
	}

	log.Println("Found ", unsynced, " cards out of sync")
	log.Println("\t", cardMoved, " moved cards")
	log.Println("\t", cardDeleted, " deleted cards")
	log.Println("\t", closed, " closed cards")
	log.Println("\t", listArchived, " archived in lists")
	log.Println("\t", listMoved, " moved lists")
	log.Println("\t", successfullyDated, "/", unsynced, " successfully dated")

	return nil
}
