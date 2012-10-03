// Generated by CoffeeScript 1.3.3
(function() {
  var Game;

  Game = (function() {

    function Game() {
      var initPos;
      this.gamers = {};
      initPos = 440 / 2 - 40;
      this.positions = [initPos - 60, initPos + 60];
    }

    Game.prototype.addGamer = function(sid, socket, side) {
      this.gamers[sid] = {
        socket: socket,
        state: 0,
        side: side,
        pos: this.positions[side]
      };
      return this.tellSide(sid);
    };

    Game.prototype.tellSide = function(sid) {
      return this.gamers[sid].socket.emit('joined', this.gamers[sid].side);
    };

    Game.prototype.sendMove = function(sid) {
      return this.gamers[sid].socket.emit('move', {
        positions: this.positions
      });
    };

    Game.prototype.sendMoveAll = function() {
      var sid, _results;
      _results = [];
      for (sid in this.gamers) {
        _results.push(this.sendMove(sid));
      }
      return _results;
    };

    Game.prototype.setState = function(sid, state) {
      return this.gamers[sid].state = state;
    };

    Game.prototype.detectMove = function() {
      var gamer, sid, _ref, _results;
      _ref = this.gamers;
      _results = [];
      for (sid in _ref) {
        gamer = _ref[sid];
        if (gamer.state === -1) {
          gamer.pos -= 10;
        } else if (gamer.state === 1) {
          gamer.pos += 10;
        }
        if (gamer.pos < 0) {
          gamer.pos = 0;
        }
        if (gamer.pos > 440 - 55) {
          gamer.pos = 440 - 55;
        }
        _results.push(this.positions[gamer.side] = gamer.pos);
      }
      return _results;
    };

    Game.prototype.oneQuitted = function(sidQuit) {
      var gamer, sid, _ref, _results;
      delete this.gamers[sid];
      _ref = this.gamers;
      _results = [];
      for (sid in _ref) {
        gamer = _ref[sid];
        if (sidQuit !== sid) {
          _results.push(gamer.socket.emit('quit', sid));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    return Game;

  })();

  module.exports = Game;

}).call(this);