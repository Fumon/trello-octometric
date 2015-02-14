package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"

	"github.com/VojtechVitek/go-trello"
)

var servport = ":6862"

var addr = flag.String("addr", "", "The address prefix to send to trello")
var usertoken = flag.String("token", "", "The user token to use when requesting")
var apikey = flag.String("apikey", "", "The application key to use")
var model = flag.String("model", "", "The model to monitor")

func main() {
	flag.Parse()

	http.HandleFunc("/webhook/todo/", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "HEAD":
			// Just trello checking that we exist. Return 200 OK.
			// TODO confirm this is from Trello
			log.Println("Got a knock from trello")
			w.WriteHeader(http.StatusOK)
			return
		case "POST":
			// Got data from trello
			// TODO confirm this is from Trello
			decoder := json.NewDecoder(r.Body)
			var h map[string]json.RawMessage
			err := decoder.Decode(&h)
			if err != nil {
				log.Fatal("Problem reading data! : ", err)
			}

			var t trello.Action
			err = json.Unmarshal(h["action"], &t)
			if err != nil {
				log.Fatal("Problem unmarshalling into trello.Action: ", err)
			}

			outstring, _ := json.MarshalIndent(t, "", "  ")
			log.Println("Data: ", string(outstring))
			return
		case "GET":
			log.Println("Look! A GET!")
			w.WriteHeader(http.StatusOK)
			return
		default:
			log.Println("Got a ", r.Method, " request")
			return
		}
	})

	go func() {
		// Send request for webhook
		// JSON Body
		jsonBody := fmt.Sprint(
			`{"description": "Test Webhook",`,
			`"callbackURL": "`, *addr, servport, `/webhook/todo/",`,
			`"idModel": "`, *model, `"}`)
		log.Println("Sending: ", jsonBody)
		buf := bytes.NewBufferString(jsonBody)

		resp, err := http.Post(
			fmt.Sprintf("https://trello.com/1/tokens/%v/webhooks/?key=%v",
				*usertoken, *apikey),
			"application/json",
			buf)
		if err != nil {
			log.Fatal("Problem sending request: ", err)
		}

		webreturn, err := ioutil.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			log.Fatal("Issue with request response: ", err)
		}

		fmt.Println("Trello response: ", string(webreturn))
	}()

	log.Println("Listening...")
	log.Fatal(http.ListenAndServe("0.0.0.0"+servport, nil))
}
