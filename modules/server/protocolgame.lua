-- @docclass
ProtocolLogin = extends(Protocol)

function ProtocolLogin:sendError(error)
  local msg = OutputMessage.create()
  msg:addU8(20)
  msg:addString(error)
  self:send(msg)
end

function ProtocolLogin:parseFirstMessage(msg)
  local osType = msg:getU16()
  local protocolVersion = msg:getU16()

  local datSignature = msg:getU32()
  local sprSignature = msg:getU32()
  local picSignature = msg:getU32()

  if not msg:decryptRsa(msg:getUnreadSize(), RSA_P, RSA_Q, RSA_D) then
    self:disconnect()
    return
  end

  local xteaKey1 = msg:getU32()
  local xteaKey2 = msg:getU32()
  local xteaKey3 = msg:getU32()
  local xteaKey4 = msg:getU32()

  -- no need to read anything else.

  self:setXteaKey(xteaKey1, xteaKey2, xteaKey3, xteaKey4)
  self:enableXteaEncryption()

  self:sendError('This server does not support this protocol.')
  self:disconnect()
end
