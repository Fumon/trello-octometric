var trello = require('node-trello');
var t = new trello("appkey", "usertoken");
var Promise = require("bluebird");

// Trello resolver 
var tresolve = function(resolve, reject) {
  return function(err, data) {
    if(err) {
      reject(err);
    } else {
      resolve(data);
    }
  };
};

var gettrello = function() {
  var args = Array.prototype.slice.apply(arguments);
  return new Promise(function(resolve,reject) {
    args.push(tresolve(resolve,reject));
    t.get.apply(t,args);
  });
};


// Get a count of all cards ever in board
var allcards = gettrello("/1/boards/targetboard/actions", { filter: "createCard", format: "list", fields: "data,date", memberCreator: "false", limit: 50});

allcards.then(function(val) {
  console.log(val);
});
