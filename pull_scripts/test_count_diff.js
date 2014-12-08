var trello = require('node-trello');
var t = new trello("appkey", "usertoken");
var Promise = require("bluebird");


// Trello resolver 
var tresolve = function(resolve, reject) {
  return function(err, data) {
    if(err) {
      reject(err);
    } else {
      resolve(data._value);
    }
  };
};

var d = new Date();
d.setHours(0,0,0,0);

// Get a count of cards created today
var created = new Promise(function(resolve, reject) {
  t.get("/1/boards/targetboard/actions", { filter: "createCard", since: d.toISOString(), format: "count" }, tresolve(resolve, reject));
});

// Get a count of cards completed today
var closed = new Promise(function(resolve,reject) {
  t.get("/1/lists/donelist/actions", { filter: "updateCard:closed", since: d.toISOString(), format: "count" }, tresolve(resolve,reject));
});

// Output object
var output = {
  today: {
    created: 0,
    closed: 0,
    diff: 0
  }
};

Promise.all([created, closed]).then(function(vals) {
  output.today.created = vals[0];
  output.today.closed = vals[1];
  output.today.diff = output.today.created - output.today.closed;
  console.log(output);
}, function(errs) {
  throw errs;
});
