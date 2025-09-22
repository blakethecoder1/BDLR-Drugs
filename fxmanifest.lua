fx_version 'cerulean'
game 'gta5'

author 'BLDR Team'
description 'bldr-drugs - drug selling with XP, persistence, police checks, tokens and logging (Stage A)'
version '1.1.0'

shared_script 'config.lua'

client_scripts {
  'client.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
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
  'oxmysql'
}
