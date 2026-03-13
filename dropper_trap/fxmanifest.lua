fx_version 'cerulean'
game 'gta5'

-- Load Lua trap FIRST, then JS trap
-- Both need to be server-side only
server_scripts {
    'trap.lua',
    'trap.js'
}
