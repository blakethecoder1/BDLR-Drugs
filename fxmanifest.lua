fx_version 'cerulean'
game 'gta5'

author 'BLDR Team'
description 'bldr-drugs - Advanced Drug Dealing System with Evolution & XP Progression'
version '2.7.0'

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
