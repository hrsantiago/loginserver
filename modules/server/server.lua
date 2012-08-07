ServerManager = {}

OTSERV_RSA  = "1091201329673994292788609605089955415282375029027981291234687579" ..
              "3726629149257644633073969600111060390723088861007265581882535850" ..
              "3429057592827629436413108566029093628212635953836686562675849720" ..
              "6207862794310902180176810615217550567108238764764442605581471797" ..
              "07119674283982419152118103759076030616683978566631413"

RSA_P = "14299623962416399520070177382898895550795403345466153217470516082934737582776038882967213386204600674145392845853859217990626450972452084065728686565928113"
RSA_Q = "7630979195970404721891201847792002125535401292779123937207447574596692788513647179235335529307251350570728407373705564708871762033017096809910315212884101"
RSA_D = "46730330223584118622160180015036832148732986808519344675210555262940258739805766860224610646919605860206328024326703361630109888417839241959507572247284807035235569619173792292786907845791904955103601652822519121908367187885509270025388641700821735345222087940578381210879116823013776808975766851829020659073"

local server
local protocols
local database
local motd
local worlds
local endpoints

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
  database:connect("127.0.0.1", "root", "", "pserv", 3306)

  protocols = {}
  motd = {id=1, text='No current information.'}
  worlds = {}
  endpoints = {}

  ServerManager.update()

  server = Server.create(7171)
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
    local endpoint = {}
    local id = endpointsResult:getDataInt('id')
    endpoint.ip = stringtoip(endpointsResult:getDataString('ip'))
    endpoint.netmask = endpointsResult:getDataInt('netmask')
    endpoints[id] = endpoint
  end

  -- update worlds endpoints
  local worldEndpointsResult = database:storeQuery('SELECT `world_id`, `endpoint_id`, `port` FROM `world_endpoints`')
  if worldEndpointsResult then
    local worldId = worldEndpointsResult:getDataInt('world_id')
    local endpointId = worldEndpointsResult:getDataInt('endpoint_id')
    local port = worldEndpointsResult:getDataInt('port')

    local world = worlds[worldId]
    world.endpoints[endpointId] = {port=port}
    world.endpoints.count = world.endpoints.count + 1
  end

  scheduleEvent(ServerManager.update, 1000)
end

function ServerManager.getMotd()
  return motd
end

function ServerManager.getWorld(id)
  local world = {}
  world.name = worlds[id].name

  local worldEndpoints = worlds[id].endpoints
  for key,value in ipairs(worldEndpoints) do
    local endpoint = endpoints[key]
    world.ip = endpoint.ip
    -- todo: check netmask
    world.port = value.port
  end

  return world
end

function ServerManager.getWorldCount()
  return worlds.count
end
