// Generated by CoffeeScript 1.3.3
(function() {
  var Gamer, app, count, express, gamers, io, port, routes;

  express = require('express');

  routes = require('./routes');

  io = require('socket.io');

  app = module.exports = express.createServer();

  app.configure(function() {
    app.set("views", __dirname + "/views");
    app.set("view engine", "jade");
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(app.router);
    return app.use(express["static"](__dirname + "/public"));
  });

  app.configure("development", function() {
    return app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
  });

  port = process.env['app_port'] || 3000;

  app.configure('production', function() {
    return app.use(express.errorHandler());
  });

  app.get('/', routes.index);

  app.get('/about', routes.about);

  app.get('/login', routes.loginPage);

  app.post('/login', routes.loginAction);

  app.listen(port);

  console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);

  Gamer = (function() {

    function Gamer(socket) {
      this.socket = socket;
    }

    Gamer.prototype.yourSide = function(side) {
      this.side = side != null ? side : 0;
      console.log("emitting his side, can you here me?");
      return this.socket.emit('joined', this.side);
    };

    return Gamer;

  })();

  gamers = {};

  count = 0;

  io = io.listen(app);

  io.sockets.on('connection', function(socket) {
    console.log("Have a connection: " + socket.id);
    socket.on('join', function(data) {
      var gamer, id, _results;
      console.log("I can has join: " + socket.id);
      if (count > 0) {
        console.log('Second player, he finally came...');
      }
      gamers[socket.id] = new Gamer(socket);
      gamers[socket.id].yourSide(count);
      count++;
      _results = [];
      for (id in gamers) {
        gamer = gamers[id];
        if (id !== socket.id) {
          _results.push(gamer.socket.emit('state', data));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    });
    socket.on('state', function(data) {
      var gamer, id, _results;
      console.log("He told me that he moved " + data.moved);
      _results = [];
      for (id in gamers) {
        gamer = gamers[id];
        if (id !== socket.id) {
          _results.push(gamer.socket.emit('state', data));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    });
    return socket.on('disconnect', function() {
      console.log("He disconnected: " + socket.id);
      return delete gamers[socket.id];
    });
  });

}).call(this);