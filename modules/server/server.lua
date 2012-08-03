ServerManager = {}

RSA_P = "14299623962416399520070177382898895550795403345466153217470516082934737582776038882967213386204600674145392845853859217990626450972452084065728686565928113"
RSA_Q = "7630979195970404721891201847792002125535401292779123937207447574596692788513647179235335529307251350570728407373705564708871762033017096809910315212884101"
RSA_D = "46730330223584118622160180015036832148732986808519344675210555262940258739805766860224610646919605860206328024326703361630109888417839241959507572247284807035235569619173792292786907845791904955103601652822519121908367187885509270025388641700821735345222087940578381210879116823013776808975766851829020659073"

local server
local protocols
local database

function Server:onAccept(connection, errorMessage, errorValue)
  server:acceptNext()

  protocol = ProtocolGeneric.create()
  protocol:enableChecksum()
  protocol:setConnection(connection)
  protocol:recv()

  ServerManager.setProtocol(connection, protocol)
end

function ServerManager.init()
  database = DatabaseMySQL.create()
  database:connect("189.55.105.125", "baxnie", "123456", "pserv", 3306)

  server = Server.create(7171)
  server:acceptNext()
  protocols = {}
end

function ServerManager.terminate()
  server = nil
  protocols = nil
  database = nil
end

function ServerManager.setProtocol(connection, protocol)
  protocols[connection] = protocol
end

function ServerManager.getDatabase()
  return database
end
