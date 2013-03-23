#include <framework/core/application.h>
#include <framework/core/resourcemanager.h>
#include <framework/luaengine/luainterface.h>
#ifdef FW_SQL
#include <framework/sql/mysql.h>
#endif

int main(int argc, const char* argv[])
{
    std::vector<std::string> args(argv, argv + argc);

    // setup application name and version
    g_app.setName("Login Server");
    g_app.setCompactName("loginserver");
    g_app.setVersion("0.1.0_dev");

    // initialize application framework and otclient
    g_app.init(args);

    // find script init.lua and run it
    g_resources.discoverWorkDir("init.lua");
    if(!g_lua.safeRunScript("init.lua"))
        g_logger.fatal("Unable to run script init.lua!");

    // the run application main loop
    g_app.run();

    // unload modules
    g_app.deinit();

    // terminate everything and free memory
    g_app.terminate();
    return 0;
}
