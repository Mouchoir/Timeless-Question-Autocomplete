// Runs tests/harness.lua against the shipped addon files inside a real Lua VM
// (fengari) with a mock WoW client. Usage:
//   npm install
//   node tests/run.js          # enUS
//   node tests/run.js frFR
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const addon = path.join(__dirname, '..', 'addon', 'TimelessQuestion');
const read = (name) => fs.readFileSync(path.join(addon, name), 'utf8');

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const setGlobal = (name, value) => {
    lua.lua_pushstring(L, to_luastring(value));
    lua.lua_setglobal(L, to_luastring(name));
};

setGlobal('LOCALE_SOURCE', read('Locale.lua'));
setGlobal('ANSWERS_SOURCE', read('Answers.lua'));
setGlobal('CORE_SOURCE', read('Core.lua'));
setGlobal('LOCALE_UNDER_TEST', process.argv[2] || 'enUS');

const harness = fs.readFileSync(path.join(__dirname, 'harness.lua'), 'utf8');
if (lauxlib.luaL_dostring(L, to_luastring(harness)) !== lua.LUA_OK) {
    console.error('lua error: ' + lua.lua_tojsstring(L, -1));
    process.exit(1);
}

lua.lua_getglobal(L, to_luastring('TEST_FAILURES'));
process.exit(lua.lua_tointeger(L, -1) === 0 ? 0 : 1);
