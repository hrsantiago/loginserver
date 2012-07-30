ServerManager = {}

local server
local protocols

function Server:onAccept(connection, errorMessage, errorValue)
  print('accepted!')
  server:acceptNext()

  protocol = ProtocolGeneric.create()
  protocol:enableChecksum()
  protocol:setConnection(connection)
  protocol:recv()

  ServerManager.setProtocol(connection, protocol)
end

function ServerManager.init()
  print('Hello, I am the Login Server =]')

  server = Server.create(7171)
  server:acceptNext()
  protocols = {}
end

function ServerManager.terminate()
  print('Bye bye, see you around ^.^')

  server = nil
  protocols = nil
end

function ServerManager.setProtocol(connection, protocol)
  protocols[connection] = protocol
end
