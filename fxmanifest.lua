fx_version 'cerulean'
game 'gta5'

author 'BLDR Team'
description 'Enhanced Drug selling script with UI, persistence, buyer NPCs and leveling system'
version '1.1.0'

shared_script 'config.lua'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/ui.html'
files {
    'html/ui.html',
    'html/ui.css',
    'html/ui.js',
    'html/assets/*'
}

dependencies {
  'qb-core',
  'ox_lib',
  'oxmysql'
}

lua54 'yes'