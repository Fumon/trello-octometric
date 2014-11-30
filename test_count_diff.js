var trello = require('node-trello');
var t = new trello("appkey", "usertoken");

// Get a list of cards created today
var d = new Date();
d.setHours(0,0,0,0);
t.get("/1/boards/targetboard/actions", { filter: "createCard", since: d.toISOString(), format: "count" }, function(err, data) {
  if(err) throw err;
  console.log("Cards added today: " + data._value);
  //console.log(data.actions[0].data);
  var count = data._value;
  t.get("/1/boards/targetboard/actions", { filter: "updateCard:closed", since: d.toISOString(), format: "count" }, function(err, data) {
    if(err) throw err;
    console.log("Cards archived today: " + data._value);
  });
});
