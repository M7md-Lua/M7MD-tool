fx_version 'cerulean'
game 'gta5'

author 'M7MD dev'
description 'Developer/admin helper tools (give items, copy coords)'
version '1.0.0'
lua54 'yes'

shared_script '@ox_lib/init.lua'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

