-- @docclass
ProtocolLogin = extends(Protocol)

LoginServerError = 10
LoginServerMotd = 20
LoginServerUpdateNeeded = 30
LoginServerCharacterList = 100

function ProtocolLogin:sendError(error)
  local msg = OutputMessage.create()
  msg:addU8(LoginServerError)
  msg:addString(error)
  self:send(msg)
end

function ProtocolLogin:addMotd(msg, motd)
  msg:addU8(LoginServerMotd)
  msg:addString(motd)
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

  local accountName = msg:getString()
  local accountPassword = msg:getString()

  self:setXteaKey(xteaKey1, xteaKey2, xteaKey3, xteaKey4)
  self:enableXteaEncryption()

  -- todo: remember to check attempts from every ip
  if string.len(accountName) <= 0 and string.len(accountPassword) <= 0 then
    sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  local database = ServerManager.getDatabase()
  local accountResult = database:storeQuery('SELECT * FROM accounts WHERE name=\'' .. database:escapeString(accountName) .. '\'')
  if not accountResult then
    sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  local hashPassword = accountResult:getDataString('password')
  local plainPassword = accountResult:getDataString('salt') .. accountPassword

  -- encrypt plain with desired method and compare
  if encrypt(plainPassword) ~= hashPassword then -- todo encrypt
    sendError('Your account name or password is invalid.')
    self:disconnect()
    return
  end

  -- check bans
  -- check premdays

  local msg = OutputMessage.create()
  self:addMotd(msg, 'Motd test') -- should be a global storage

  -- charlist -- todo: add cooler stuff, like outfit, level
  local accountId = accountResult:getDataInt('id')
  local charListResult = database:storeQuery('SELECT `name`, `world_id` FROM `players` WHERE `account_id` = ' .. accountId  .. ' AND `deleted` = 0'
  if not charListResult then -- todo: add a byte to show create character dialog
    sendError('This account does not contain any character yet')
    self:disconnect()
    return
  end

  local charList = {}
  local i = 1
  while true do
    charList[i] = {}
    charList[i].name = charListResult:getDataString('name')
    charList[i].worldName = 'abc'
    charList[i].worldIp = 123
    charList[i].worldPort = 7171

    local worldId = charListResult:getDataInt('world_id')
    -- get world name, ip, port

    if not charListResult:next() then
      break
    end
    i = i + 1
  end

  self:addCharacterList(msg, charList, 10) -- todo premdays

  self:send(msg)
  self:disconnect()
end
