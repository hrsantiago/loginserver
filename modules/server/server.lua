ServerManager = {}

-- CONFIG
local LISTEN_PORT = 7171

local DATABASE_HOST = "127.0.0.1"
local DATABASE_PORT = 3306
local DATABASE_USER = "root"
local DATABASE_PASS = ""
local DATABASE_NAME = "pserv"

local ATTEMPTS_BAN_TIME = 10*60 -- 10 minutes
local ATTEMPTS_COUNT = 10

local server
local protocols
local database
local motd
local worlds
local endpoints
local attempts

function Server:onAccept(connection, errorMessage, errorValue)
  if self:isOpen() then
    server:acceptNext()
  end

  if errorValue == 0 then
    protocol = ProtocolGeneric.create()
    protocol:enableChecksum()
    protocol:setConnection(connection)
    protocol:recv()

    ServerManager.setProtocol(connection, protocol)
  end
end

function ServerManager.init()
  g_crypt.rsaSetPublicKey(OTSERV_RSA, '65537')
  g_crypt.rsaSetPrivateKey(RSA_P, RSA_Q, RSA_D)
  g_crypt.rsaCheckKey()

  database = DatabaseMySQL.create()
  database:connect(DATABASE_HOST, DATABASE_USER, DATABASE_PASS, DATABASE_NAME, DATABASE_PORT)

  protocols = {}
  motd = {id=1, text='No current information.'}
  worlds = {}
  endpoints = {}
  attempts = {}

  ServerManager.update()

  server = Server.create(LISTEN_PORT)
  server:acceptNext()
end

function ServerManager.terminate()
  server:close()
  server = nil
  protocols = nil
  motd = nil
  worlds = nil
  endpoints = nil
  database = nil
end

function ServerManager.setProtocol(connection, protocol)
  protocols[connection] = protocol
end

function ServerManager.getDatabase()
  return database
end

function ServerManager.update()
  local motdResult = database:storeQuery('SELECT `id`, `text` FROM `server_motd` ORDER BY `id` DESC LIMIT 1')
  if motdResult then
    motd.id = motdResult:getDataString('id')
    motd.text = motdResult:getDataString('text')
  end

  -- update worlds
  local worldsResult = database:storeQuery('SELECT `id`, `name` FROM `worlds`')
  if worldsResult then
    worlds = { count=0 }
    while true do
      local id = worldsResult:getDataInt('id')
      local name = worldsResult:getDataString('name')
      worlds[id] = {}
      worlds[id].name = name
      worlds[id].endpoints = {count=0}
      worlds.count = worlds.count + 1
      if not worldsResult:next() then break end
    end
  end

  -- update endpoints
  local endpointsResult = database:storeQuery('SELECT `id`, `ip`, `netmask` FROM `endpoints`')
  if endpointsResult then
    endpoints = {}
    while true do
      local endpoint = {}
      endpoint.ip = stringtoip(endpointsResult:getDataString('ip'))
      endpoint.netmask = endpointsResult:getDataInt('netmask')
      endpoints[endpointsResult:getDataInt('id')] = endpoint
      if not endpointsResult:next() then break end
    end
  end

  -- update worlds endpoints
  local worldEndpointsResult = database:storeQuery('SELECT `world_id`, `endpoint_id`, `port` FROM `world_endpoints`')
  if worldEndpointsResult then
    while true do
      local worldId = worldEndpointsResult:getDataInt('world_id')
      local endpointId = worldEndpointsResult:getDataInt('endpoint_id')
      local port = worldEndpointsResult:getDataInt('port')

      local endpoint = {}
      endpoint.port = port
      endpoint.ip = endpoints[endpointId].ip
      endpoint.netmask = endpoints[endpointId].netmask

      local world = worlds[worldId]
      world.endpoints[world.endpoints.count+1] = endpoint
      world.endpoints.count = world.endpoints.count + 1

      if not worldEndpointsResult:next() then break end
    end
  end

  scheduleEvent(ServerManager.update, 1000)
end

function ServerManager.getMotd()
  return motd
end

function ServerManager.getWorld(id)
  local endpointId = math.random(1, worlds[id].endpoints.count)
  local endpoint = worlds[id].endpoints[endpointId]
  local ipList = listSubnetAddresses(endpoint.ip, endpoint.netmask)
  local ipId = math.random(1, #ipList)

  local world = {}
  world.name = worlds[id].name
  world.ip = ipList[ipId]
  world.port = endpoint.port
  return world
end

function ServerManager.getWorldCount()
  return worlds.count
end

function ServerManager.addAttempt(ip)
  local attempt = {count=0,last=0}
  if attempts[ip] then
    attempt = attempts[ip]
  end

  attempt.count = attempt.count + 1
  attempt.last = os.time()

  attempts[ip] = attempt
end

function ServerManager.isIpBanished(ip)
  local attempt = attempts[ip]
  if not attempt then
    return 0
  end

  local time = os.time()
  if time - attempt.last >= ATTEMPTS_BAN_TIME then
    attempt.count = 0
    return 0
  end

  if attempt.count >= ATTEMPTS_COUNT then
    return ATTEMPTS_BAN_TIME - (time - attempt.last)
  end

  return 0
end
