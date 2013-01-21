-- @docclass
ProtocolLogin = extends(Protocol)

LoginServerError = 10
LoginServerMotd = 20
LoginServerUpdateNeeded = 30
LoginServerCharacterList = 100
LoginServerCharacterListExtended = 101
LoginServerCreateCharacter = 102

function ProtocolLogin:disconnect()
  ServerManager.setProtocol(self:getConnection(), nil)
  Protocol.disconnect(self)
end

function ProtocolLogin:sendError(error)
  local msg = OutputMessage.create()
  msg:addU8(LoginServerError)
  msg:addString(error)
  self:send(msg)
end

function ProtocolLogin:addMotd(msg, id, text)
  msg:addU8(LoginServerMotd)
  msg:addString(id .. '\n' .. text)
end

function ProtocolLogin:addUpdateNeeded(msg)
  msg:addU8(LoginServerUpdateNeeded)
end

function ProtocolLogin:addCharacterList(msg, charList, account)
  msg:addU8(LoginServerCharacterList)
  msg:addU8(#charList)
  for i=1,#charList do
    msg:addString(charList[i].name)
    msg:addString(charList[i].worldName)
    msg:addU32(charList[i].worldIp)
    msg:addU16(charList[i].worldPort)
  end
  msg:addU16(account.premDays)
end

function ProtocolLogin:addCharacterListExtended(msg, charList, account)
  for i=1,#charList do
    charList[i].worldIp = iptostring(charList[i].worldIp)
  end
  msg:addU8(LoginServerCharacterListExtended)
  msg:addTable(charList)
  msg:addTable(account)
  msg:addString('pokecharlist.otui')
end

function ProtocolLogin:sendCreateCharacter(message)
  local msg = OutputMessage.create()
  msg:addU8(LoginServerCreateCharacter)
  msg:addString(message)
  msg:addString('pokecharcreate.otui')
  self:send(msg)
end

function ProtocolLogin:parseLoginMessage(msg)
  local connection = self:getConnection()
  local ip = connection:getIp()

  local osType = msg:getU16()
  local protocolVersion = msg:getU16()

  local datSignature = msg:getU32()
  local sprSignature = msg:getU32()
  local picSignature = msg:getU32()

  if not msg:decryptRsa(msg:getUnreadSize(), OTSERV_RSA, RSA_P, RSA_Q, RSA_D) then
    self:disconnect()
    return
  end

  local xteaKey1 = msg:getU32()
  local xteaKey2 = msg:getU32()
  local xteaKey3 = msg:getU32()
  local xteaKey4 = msg:getU32()

  local accountName = msg:getString()
  local accountPassword = msg:getString()

  self:setXteaKey(xteaKey1, xteaKey2, xteaKey3, xteaKey4)
  self:enableXteaEncryption()

  -- check ip banishment for attemps
  local banTime = ServerManager.isIpBanished(ip)
  if banTime > 0 then
    self:sendError('Your IP address is banished for ' .. math.ceil(banTime/60) .. ' minutes.')
    self:disconnect()
    return
  end

  -- check account
  local account = Account.create(accountName, accountPassword)
  if not account then
    ServerManager.addAttempt(ip)
    self:sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  -- load send stuff
  local motd = ServerManager.getMotd()
  local accountTable = {premDays = account:getPremiumDays()}
  local characterTable = account:getCharacterList()
  if not characterTable then
    self:sendCreateCharacter('Your account does not contain any character.')
    self:disconnect()
    return
  end

  -- send
  local oMsg = OutputMessage.create()
  self:addMotd(oMsg, motd.id, motd.text)

  if osType >= OsTypes.OtclientLinux then
    self:addCharacterListExtended(oMsg, characterTable, accountTable)
  else
    self:addCharacterList(oMsg, characterTable, accountTable)
  end

  self:send(oMsg)
  self:disconnect()
end

function ProtocolLogin:parseCreateCharacterMessage(msg)
  local connection = self:getConnection()
  local ip = connection:getIp()

  local osType = msg:getU16()
  local protocolVersion = msg:getU16()

  if not msg:decryptRsa(msg:getUnreadSize(), OTSERV_RSA, RSA_P, RSA_Q, RSA_D) then
    self:disconnect()
    return
  end

  local xteaKey1 = msg:getU32()
  local xteaKey2 = msg:getU32()
  local xteaKey3 = msg:getU32()
  local xteaKey4 = msg:getU32()

  local accountName = msg:getString()
  local accountPassword = msg:getString()
  local characterName = msg:getString()
  local characterGender = msg:getU8()
  local worldName = msg:getString()

  self:setXteaKey(xteaKey1, xteaKey2, xteaKey3, xteaKey4)
  self:enableXteaEncryption()

  -- check ip banishment for attemps
  local banTime = ServerManager.isIpBanished(ip)
  if banTime > 0 then
    self:sendError('Your IP address is banished for ' .. math.ceil(banTime/60) .. ' minutes.')
    self:disconnect()
    return
  end

  if string.len(characterName) < 3 then
    self:sendError('Your character name is too small.')
    self:disconnect()
    return
  end

  if string.len(characterName) > 30 then
    self:sendError('Your character name is too long.')
    self:disconnect()
    return
  end

  if hasInvalidCharacter(characterName) then
    self:sendError('Your character name contains invalid characters.')
    self:disconnect()
    return
  end

  if characterGender ~= 0 and characterGender ~= 1 then
    self:sendError('Your character gender is invalid.')
    self:disconnect()
    return
  end

  local worldId = ServerManager.getWorldId(worldName)
  if not worldId then
    self:sendError('World name is invalid.')
    self:disconnect()
    return
  end

  local account = Account.create(accountName, accountPassword)
  if not account then
    ServerManager.addAttempt(ip)
    self:sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  if account:getCharacterCount() >= 10 then
    self:sendError('Your account has too many characters.')
    self:disconnect()
    return
  end

  if not ServerManager.isCharacterNameAvailable(characterName) then
    self:sendError('A character with this name already exists.')
    self:disconnect()
    return
  end

  if not account:createCharacter(characterName, characterGender, worldId) then
    self:sendError('Could not create character. Please try again later.')
    self:disconnect()
    return
  end

  -- send
  local accountTable = {premDays = account:getPremiumDays()}
  local characterTable = account:getCharacterList()

  local oMsg = OutputMessage.create()
  if osType >= OsTypes.OtclientLinux then
    self:addCharacterListExtended(oMsg, characterTable, accountTable)
  else
    self:addCharacterList(oMsg, characterTable, accountTable)
  end

  self:send(oMsg)
  self:disconnect()
end
