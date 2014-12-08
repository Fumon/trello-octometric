var trello = require('node-trello');
var t = new trello("appkey", "usertoken");


//t.get("/1/boards/targetboard/lists", function(err, data) {
//  if (err) throw err;
//  console.log(data);
//});

//t.get("/1/lists/donelist/cards/closed", function(err, data) {
//  if (err) throw err;
//  console.log(data);
//});

t.get("/1/cards/targetcard/actions", { filter: ["createCard", "closed"], fields: "date"}, function(err, data) {
  if (err) throw err;
  console.log(data);
});
