util = require 'util'
events = require 'events'
request = require 'request'
WebSocket = require 'ws' # これは共有してもよい

class RocketIO extends events.EventEmitter
  constructor: (@url, opts = {type: 'websocket'}) ->
    # ()と->の間はあける、=は両端にspaceがあるのが望ましい
    # 引数@urlでRocketIO::urlにバインドされる
    @type = opts.type
    @config = {}

  connect: =>
    request "#{@url}/rocketio/settings", (err, res, body) => # space
      return if err or res.statusCode isnt 200 # isやisntを使う、!=は!==に変換されるので明示した方がいい
      try
        @config = JSON.parse body # JSON.parseは文法エラーで必ず落ちる、try catchでくくったほうが吉
      catch e
        console.error e
      @io = switch @type
        # 1行が79文字以内であれば短くした方が吉
        when 'websocket' then new WebSocketIO(@)
        when 'comet' then new CometIO(@)
      @io.on 'connect', =>
        @emit 'connect', @
      @io.on 'disconnect', =>
        @emit 'disconnect', @
    return @

  push: (type, data) => # space
    @io.push type, data

class WebSocketIO extends events.EventEmitter

  constructor: (rocketio) -> # space
    @rocketio = rocketio
    @connecting = false
    @on 'disconnect', =>
      setTimeout =>
        @connect()
      , 5000
    @connect()

  connect: ->
    @ws = new WebSocket @rocketio.config?.websocket # 存在確認演算子は中途で使用可能(constructorのJSON.parse失敗時)
    @ws.on 'error', (err)=>
      @connecting = no # geta6のポリシー、switch系にはon/offを用いそれ以外にはyes/noを用いる
      @emit 'disconnect'
    @ws.on 'close', =>
      @connecting = no
      @emit 'disconnect'
    @ws.on 'open', =>
      @connecting = yes
      @emit 'connect'
    @ws.on 'message', (data, flags) => # space
      try
        data = JSON.parse data
      catch e
        console.error e
      @rocketio.emit data?.type, data?.data

  push: (type, data) -> # space
    return unless @connecting
    @ws.send JSON.stringify { type: type, data: data } # ()いらないのとspace

class CometIO extends events.EventEmitter
  # classメソッドは必ず一行あける

  constructor: (rocketio) -> # space
    @rocketio = rocketio
    @post_queue = []
    @on '__session_id', (id) => # space
      @session_id = id
      @emit 'connect'
    @get()
    setInterval @flush, 1000 # これでいい

  get: =>
    url = switch typeof @session_id
      when 'string' # indentはコンテクストに依存して書く
        "#{@rocketio.config.comet}?session=#{@session_id}" # 返り値を期待する場合はこう書いた方が伝わりやすい
      else
        @rocketio.config.comet
    request url, (err, res, body) =>
      if err or res.statusCode isnt 200 # != -> isnt
        setTimeout @get, 10000 # binded
        return
      try
        data_arr = JSON.parse body
      catch e
        console.error e
      return unless data_arr instanceof Array
      setTimeout @get, 10 # binded
      for data in data_arr
        @emit data.type, data.data
        @rocketio.emit data.type, data.data

  push: (type, data) -> # space
    return unless @session_id
    @post_queue.push { type: type, data: data } # data

  flush: => # setIntervalで用いるので=>で拘束する
    return if @post_queue.length < 1
    post_data = # {}いらない
      json: JSON.stringify { session: @session_id, events: @post_queue } # ()いらない
    request.post # 長いのでこうする
      url: @rocketio.config.comet
      form: post_data
    , (err, res, body) =>
      return if err or res.statusCode isnt 200 # 明示
      @post_queue = []

exports = module.exports = RocketIO # exports = をつけたほうが親切、module自身がRocketIOオブジェクトになれる
