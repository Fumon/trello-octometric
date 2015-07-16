package main

type Action struct {
	Id   string `json:"id"`
	Data struct {
		List struct {
			Closed bool   `json:"closed"`
			Name   string `json:"name"`
			Id     string `json:"id"`
		} `json:"list"`
		ListBefore struct {
			Closed bool   `json:"closed"`
			Name   string `json:"name"`
			Id     string `json:"id"`
		} `json:"listBefore"`
		ListAfter struct {
			Closed bool   `json:"closed"`
			Name   string `json:"name"`
			Id     string `json:"id"`
		} `json:"listAfter"`
		BoardSource struct {
			Id string `json:"id"`
		} `json:"boardSource"`
		Card struct {
			Id     string `json:"id"`
			Name   string `json:"name"`
			Closed bool   `json:"closed"`
		} `json:"card"`
		Old struct {
			Closed  bool   `json:"closed"`
			IdList  string `json:"idList"`
			IdBoard string `json:"idBoard"`
		} `json:"old"`
	} `json:"data"`
	Type string `json:"type"`
	Date string `json:"date"`
}

type DebugAction struct {
	Action
	OStr string
}

type BoardCard struct {
	Id               string   `json:"id"`
	Closed           bool     `json:"closed"`
	IdList           string   `json:"idList"`
	IdBoard          string   `json:"idBoard"`
	Name             string   `json:"name"`
	DateLastActivity string   `json:"dateLastActivity"`
	Actions          []Action `json:"actions"`
}

// Struct for processing
type WebhookAction struct {
	Action `json:"action"`
}
