Account = {}

function Account.create(name, password)
  local db = ServerManager.getDatabase()
  local data = db:storeQuery('SELECT * FROM accounts WHERE name=' .. db:escapeString(name))
  if not data then
    return nil
  end

  local hashPassword = data:getDataString('password')
  local plainPassword = data:getDataString('salt') .. password
  if g_crypt.sha1Encode(plainPassword, true) ~= hashPassword:upper() then
    return nil
  end

  local account = {}
  account.id = data:getDataInt('id')
  account.name = name
  account.password = password
  account.premiumEnd = data:getDataLong('premend')
  account.data = data
  setmetatable(account, { __index = Account })
  return account
end

function Account:getPremiumDays()
  return math.ceil(math.max(self.premiumEnd - os.time(), 0) / 86400);
end

function Account:getCharacterList()
  local db = ServerManager.getDatabase()
  local data = db:storeQuery('SELECT `name`, `level`, `world_id`, `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `lookaddons` FROM `players` WHERE `account_id` = ' .. self.id  .. ' AND `deleted` = 0')
  if not data then
    return nil
  end

  local charList = {}
  charList.otui = ''
  local i = 1
  while true do
    charList[i] = {}
    charList[i].name = data:getDataString('name')
    charList[i].lvl = data:getDataInt('level')

    local outfit = {}
    outfit.type = data:getDataInt('looktype')
    outfit.head = data:getDataInt('lookhead')
    outfit.body = data:getDataInt('lookbody')
    outfit.legs = data:getDataInt('looklegs')
    outfit.feet = data:getDataInt('lookfeet')
    outfit.addons = data:getDataInt('lookaddons')
    charList[i].outfit = outfit

    local world = ServerManager.getWorld(data:getDataInt('world_id'))
    charList[i].worldName = world.name
    charList[i].worldIp = world.ip
    charList[i].worldPort = world.port

    if not data:next() then break end
    i = i + 1
  end

  return charList
end

function Account:getCharacterCount()
  local db = ServerManager.getDatabase()
  local data = db:storeQuery('SELECT COUNT(*) FROM `players` WHERE `account_id` = ' .. self.id)
  if data then
    return data:getRowCount()
  end
  return 0
end

function Account:createCharacter(name, gender, world)
  local level = 1
  local vocationId = 18
  local healthMax = 150
  local exp = 0
  local lookType = gender == 0 and 676 or 675
  local lookHead = 97
  local lookBody = 0
  local lookLegs = 95
  local lookFeet = 94
  local magicLevel = 0
  local manaMax = 0
  local capMax = 0
  local town = 1

  local db = ServerManager.getDatabase()
  local query = "INSERT INTO `players` " ..
    "(`id`, `name`, `world_id`, `group_id`, `account_id`, `level`, `vocation`, `health`, `healthmax`, `experience`, `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `lookaddons`, `maglevel`, `mana`, `manamax`, `manaspent`, `soul`, `town_id`, `posx`, `posy`, `posz`, `conditions`, `cap`, `sex`, `lastlogin`, `lastip`, `skull`, `skulltime`, `save`, `rank_id`, `guildnick`, `lastlogout`, `blessings`, `online`)" ..
    "VALUES (NULL, " .. db:escapeString(name) .. ", " .. world .. ", 1, " .. self.id .. ", " .. level .. ", " .. vocationId .. ", " .. healthMax .. ", " .. healthMax .. ", " .. exp .. ", " .. lookBody .. ", " .. lookFeet .. ", " .. lookHead .. ", " .. lookLegs .. ", " .. lookType .. ", 0, " .. magicLevel .. ", " .. manaMax .. ", " .. manaMax .. ", 0, 100, " .. town .. ", 0, 0, 0, 0, " .. capMax .. ", " .. gender .. ", 0, 0, 0, 0, 1, 0, '', 0, 0, 0)"

  return db:executeQuery(query)
end
