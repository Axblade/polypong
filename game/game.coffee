# Here is all our socket machimery.
# We have server events:
# - join - user joins the game
# - state - user updates his position
# - disconnect - user disconnects
# And we have client events, generated by server:
# - joined - tell him about success join and which side he will be playing (left or right for now)
# - busy - room is full of players
# - state - update my and others positions
# - quit - some user quitted

GameCore = require './game.core'
cookie = require 'cookie'
timers = require 'timers'

module.exports = class Game extends GameCore

  constructor: ->
    super()

    @gamers = {}
    initPos = @canvasHeight / 2 - 40
    @gs = [{pos: initPos - @racketHeight, dir: @dirIdle, updates: [], lastSeq: 0},
           {pos: initPos + @racketHeight, dir: @dirIdle, updates: [], lastSeq: 0}]
    @ballResetOffset = 50
    @scores = [0, 0]
    @count = 0
    @inDaLoop = false

  addGamer: (sid, socket, side) ->
    @gamers[sid] = {socket: socket, updates: [], side: side, pos: @gs[side].pos, lastSeq: 0}
    @sendJoined sid

  sendJoined: (sid) ->
    @gamers[sid].socket.emit 'joined', @gamers[sid].side

  sendMove: (sid) ->
    g = @gamers[sid]
    @gs[g.side].updates = g.updates
    g.socket.emit 'move', {gamers: @gs, ball: {pos: @ballPosition, v: @ballV, angle: @angle}}

  sendMoveAll: ->
    @debug "Senging move to all with last seqs:"
    for sid of @gamers
      @debug "lastSeq: #{@gamers[sid].lastSeq}"
      @sendMove sid

  sendScore: (sid) ->
    @gamers[sid].socket.emit 'score', {scores: @scores}

  sendScoreAll: ->
    for sid of @gamers
      @sendScore sid

  updateState: (sid, dir, seq) ->
    @gamers[sid].updates.push {dir: dir, seq: seq, t: @time()}

  placeBall: (side) ->
    @ballPosition[1] = @gs[side].pos + @racketHeight / 2
    if side == 0
      @ballPosition[0] = @ballResetOffset
      @angle = Math.asin((@gs[1].pos - @gs[0].pos + @racketHeight) / @canvasWidth)
    else
      @ballPosition[0] = @canvasWidth - @ballResetOffset
      @angle = Math.PI + Math.asin((@gs[1].pos - @gs[0].pos + @racketHeight) / @canvasWidth)

  moveRackets: (lastTime) ->
    for sid, gamer of @gamers
      gamer.pos = @moveRacket gamer.dir, gamer.updates, gamer.pos, @updateTime, lastTime
      @gs[gamer.side].pos = gamer.pos
      if gamer.updates.length
        lastUpdate = gamer.updates[gamer.updates.length-1]
        gamer.dir = lastUpdate.dir
        @gs[gamer.side].lastSeq = lastUpdate.seq
        @debug "Last processed seq: #{lastUpdate.seq}"
      gamer.updates = []
      @gs[gamer.side].updates = [] # FIXME seems wrong, clear after updates sent only

  checkScoreUpdate: ->
    if @ballPosition[0] < 0 or @ballPosition[0] > @canvasWidth - @ballSize
      side = -1
      if @ballPosition[0] < 0
        @scores[1] += 1
        side = 0
      if @ballPosition[0] > @canvasWidth - @ballSize
        @scores[0] += 1
        side = 1
      @placeBall side 
      @sendScoreAll()

  startLoop: ->
    return if @inDaLoop
    @gameLoop = timers.setInterval =>
      @gameStep()
    , @dt
    @inDaLoop = true

  endLoop: ->
    return unless @inDaLoop
    timers.clearInterval @gameLoop
    @inDaLoop = false
    @scores = [0, 0]

  gameStep: ->
    @updateTime = @time()
    lastTime = @updateTime - @dt # FIXME do as in client code
    @moveRackets lastTime
    @moveBall()
    @checkScoreUpdate()
    @sendMoveAll()

  oneQuitted: (sidQuit) ->
    delete @gamers[sidQuit]
    for sid, gamer of @gamers
      gamer.socket.emit('quit', sid) if (sidQuit != sid)

  connect: (socket) ->
    sid = cookie.parse(socket.handshake.headers.cookie)['connect.sid']
    @info "Have a connection: #{sid} (socket id: #{socket.id})"

    socket.on 'join', (data) =>
      if sid of @gamers
        @sendJoined sid
        @sendMove sid
        return
      if @count == 2
        socket.emit 'busy'
        return
      @info "I can has join: #{sid}"
      @addGamer sid, socket, @count
      @count++
      @startLoop() if @count > 0
      @sendMove sid
      @sendScore sid

    socket.on 'state', (data) =>
      @debug "Player #{data.side} moving #{data.dir}"
      @updateState sid, data.dir, data.seq

    socket.on 'disconnect', =>
      return unless sid of @gamers && @gamers[sid].socket.id == socket.id
      @info "Disconnecting: #{sid}"
      @oneQuitted sid
      @count--
      @endLoop() if @count == 0
