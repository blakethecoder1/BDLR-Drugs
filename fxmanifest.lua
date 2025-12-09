fx_version 'cerulean'
game 'gta5'

author 'blakethepet'
description 'bldr-drugs - Advanced Drug Dealing System with UI Customization & Evolution'
version '2.8.0'

shared_script 'config.lua'

client_scripts {
  'client.lua'
}

server_scripts {
  'server.lua'
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
  'html/app.js',
  'html/ui.css',
  'html/ui.html',
  'html/ui.js'
}

dependencies {
  'qb-core',
  'ox_lib',
  'oxmysql',
  'qb-target'  -- Third-eye system
}
