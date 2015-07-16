package main

import "flag"

var usertoken = flag.String("token", "", "The user token to use when requesting")
var apikey = flag.String("apikey", "", "The application key to use")
var model = flag.String("model", "", "The model to monitor")

func main() {
	flag.Parse()

	//b, _ := queryList("50bc4dcfe30e85380200e8ac", "updateList", *apikey, *usertoken)
	//b, _ := queryBoard(*model, "moveCardFromBoard", *apikey, *usertoken)
	//debugJSON(b)

	syncDB(*model, *apikey, *usertoken)
}
