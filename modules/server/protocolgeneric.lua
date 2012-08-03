-- @docclass
ProtocolGeneric = extends(Protocol)

function ProtocolGeneric:onRecv(msg)
  local connection = self:getConnection()

  local opcode = msg:getU8()
  if opcode == 0x01 then
    local protocol = ProtocolLogin.create()
    ServerManager.setProtocol(connection, protocol)
    protocol:enableChecksum()
    protocol:setConnection(connection)
    protocol:parseFirstMessage(msg)
  elseif opcode == 0x0A then
    local protocol = ProtocolGame.create()
    ServerManager.setProtocol(connection, protocol)
    protocol:enableChecksum()
    protocol:setConnection(connection)
    protocol:parseFirstMessage(msg)
  else
    self:disconnect()
    ServerManager.setProtocol(connection, nil)
  end
end
