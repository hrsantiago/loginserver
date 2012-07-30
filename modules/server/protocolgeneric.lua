-- @docclass
ProtocolGeneric = extends(Protocol)

function ProtocolGeneric:onRecv(msg)
  local opcode = msg:getU8()
  if opcode == 0x01 then
    print('protocollogin')
    local protocol = ProtocolLogin.create()
    local connection = self:getConnection()
    protocol:setConnection(connection)
    ServerManager.setProtocol(connection, protocol)
    protocol:parseFirstMessage(msg)
  elseif opcode == 0x0A then

  end
end
