-- @docclass
ProtocolLogin = extends(Protocol)

LoginServerError = 10
LoginServerMotd = 20
LoginServerUpdateNeeded = 30
LoginServerCharacterList = 100
LoginServerCharacterListExtended = 101
LoginServerCreateCharacter = 102

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

function ProtocolLogin:addCharacterList(msg, charList, premDays)
  msg:addU8(LoginServerCharacterList)
  msg:addU8(#charList)
  for i=1,#charList do
    msg:addString(charList[i].name)
    msg:addString(charList[i].worldName)
    msg:addU32(charList[i].worldIp)
    msg:addU16(charList[i].worldPort)
  end
  msg:addU16(premDays)
end

function ProtocolLogin:addCharacterListExtended(msg, charList, premDays)
  msg:addU8(LoginServerCharacterListExtended)
  msg:addU8(#charList)
  for i=1,#charList do
    msg:addString(charList[i].name)
    msg:addString(charList[i].worldName)
    msg:addU32(charList[i].worldIp)
    msg:addU16(charList[i].worldPort)
    msg:addU16(charList[i].level)
    msg:addU8(charList[i].lookType)
    msg:addU8(charList[i].lookHead)
    msg:addU8(charList[i].lookBody)
    msg:addU8(charList[i].lookLegs)
    msg:addU8(charList[i].lookFeet)
    msg:addU8(charList[i].lookAddons)
  end
  msg:addU16(premDays)
end

function ProtocolLogin:sendCreateCharacter()
  local msg = OutputMessage.create()
  msg:addU8(LoginServerCreateCharacter)
  self:send(msg)
end

function ProtocolLogin:parseFirstMessage(msg)
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
  local database = ServerManager.getDatabase()
  local accountResult = database:storeQuery('SELECT * FROM accounts WHERE name=' .. database:escapeString(accountName))
  if not accountResult then
    ServerManager.addAttempt(ip)
    self:sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  -- check password
  local hashPassword = accountResult:getDataString('password')
  local plainPassword = accountResult:getDataString('salt') .. accountPassword
  if g_crypt.sha1Encode(plainPassword, true) ~= hashPassword:upper() then
    ServerManager.addAttempt(ip)
    self:sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  -- check premdays
  local time = os.time()
  local premEnd = accountResult:getDataLong('premend')
  local premDays = math.ceil(math.max(premEnd - time, 0) / 86400);

  -- load characters
  local accountId = accountResult:getDataInt('id')
  local charListResult = database:storeQuery('SELECT `name`, `level`, `world_id`, `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `lookaddons` FROM `players` WHERE `account_id` = ' .. accountId  .. ' AND `deleted` = 0')
  if not charListResult then
    self:sendCreateCharacter(msg)
    self:disconnect()
    return
  end

  local msg = OutputMessage.create()

  -- motd
  local motd = ServerManager.getMotd()
  self:addMotd(msg, motd.id, motd.text)

  -- charlist
  local charList = {}
  local i = 1
  while true do
    charList[i] = {}
    charList[i].name = charListResult:getDataString('name')
    charList[i].level = charListResult:getDataInt('level')
    charList[i].lookType = charListResult:getDataInt('looktype')
    charList[i].lookHead = charListResult:getDataInt('lookhead')
    charList[i].lookBody = charListResult:getDataInt('lookbody')
    charList[i].lookLegs = charListResult:getDataInt('looklegs')
    charList[i].lookFeet = charListResult:getDataInt('lookfeet')
    charList[i].lookAddons = charListResult:getDataInt('lookaddons')
    
    local world = ServerManager.getWorld(charListResult:getDataInt('world_id'))
    charList[i].worldName = world.name
    charList[i].worldIp = world.ip
    charList[i].worldPort = world.port

    if not charListResult:next() then break end
    i = i + 1
  end

  if osType < OsTypes.OtclientLinux then
    self:addCharacterListExtended(msg, charList, premDays)
  else
    self:addCharacterList(msg, charList, premDays)
  end

  self:send(msg)
  ServerManager.setProtocol(connection, nil)
  self:disconnect()
end
