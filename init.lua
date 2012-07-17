-- this is the first file executed when the application starts
-- we have to load the first modules form here

-- setup logger
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. ".log")

-- print first terminal message
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ') built on ' .. g_app.getBuildDate())

--add base folder to search path
g_resources.addSearchPath(g_resources.getWorkDir())

-- add modules directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. "modules", true) then
  g_logger.fatal("Unable to add modules directory to the search path.")
end

g_modules.discoverModules()

-- core modules 0-99
g_modules.autoLoadModules(99);
g_modules.ensureModuleLoaded("corelib")

-- server modules 100-999
g_modules.autoLoadModules(999);
g_modules.ensureModuleLoaded("server")
