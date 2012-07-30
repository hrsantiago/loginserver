-- @docclass
ProtocolLogin = extends(Protocol)

LoginServerError = 10
LoginServerMotd = 20
LoginServerUpdateNeeded = 30
LoginServerCharacterList = 100

function ProtocolLogin:login(host, port, accountName, accountPassword)
  if string.len(accountName) == 0 or string.len(accountPassword) == 0 then
    signalcall(self.onError, self, tr("You must enter an account name and password."))
    return
  end
  if string.len(host) == 0 or port == nil or port == 0 then
    signalcall(self.onError, self, tr("You must enter a valid server address and port."))
    return
  end

  self.accountName = accountName
  self.accountPassword = accountPassword
  self.connectCallback = sendLoginPacket

  self:connect(host, port)
end

function ProtocolLogin:cancelLogin()
  self:disconnect()
end

function ProtocolLogin:sendLoginPacket()
  local msg = OutputMessage.create()
  msg:addU8(ClientOpcodes.ClientEnterAccount)
  msg:addU16(g_game.getOsType())
  msg:addU16(g_game.getClientVersion())

  msg:addU32(g_things.getDatSignature())
  msg:addU32(g_sprites.getSprSignature())
  msg:addU32(PIC_SIGNATURE)

  local paddingBytes = 128
  msg:addU8(0) -- first RSA byte must be 0
  paddingBytes = paddingBytes - 1

  -- xtea key
  self:generateXteaKey()
  local xteaKey = self:getXteaKey()
  msg:addU32(xteaKey[1])
  msg:addU32(xteaKey[2])
  msg:addU32(xteaKey[3])
  msg:addU32(xteaKey[4])
  paddingBytes = paddingBytes - 16

  if g_game.getFeature(GameProtocolChecksum) then
    self:enableChecksum()
  end

  if g_game.getFeature(GameAccountNames) then
    msg:addString(self.accountName)
    msg:addString(self.accountPassword)
    paddingBytes = paddingBytes - (4 + string.len(self.accountName) + string.len(self.accountPassword))
  else
    msg:addU32(tonumber(self.accountName))
    msg:addString(self.accountPassword)
    paddingBytes = paddingBytes - (6 + string.len(self.accountPassword))
  end

  msg:addPaddingBytes(paddingBytes, 0)
  msg:encryptRsa(128, g_game.getRsa())

  self:send(msg)
  self:enableXteaEncryption()
  self:recv()
end

function ProtocolLogin:onConnect()
  self:sendLoginPacket()
end

function ProtocolLogin:onRecv(msg)
  self:parseFirstMessage(msg)
  self:disconnect()
end

function ProtocolLogin:parseFirstMessage(msg)
  local osType = msg:getU16()
  local clientVersion = msg:getU16()
  print(osType, clientVersion)

  local datSignature = msg:getU32()
  local sprSignature = msg:getU32()
  local picSignature = msg:getU32()
end
