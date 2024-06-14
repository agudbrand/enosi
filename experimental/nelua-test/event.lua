local aster = require "nelua.aster"
local shaper = aster.shaper
local eventl = {}

local l = require "lpegrex"

local grammar =
[==[
	chunk         <-- SKIP `event` NAME
	NAME          <-- !KEYWORD {NAME_PREFIX NAME_SUFFIX?} SKIP
	NAME_PREFIX   <-- [_%a]
	NAME_SUFFIX   <-- [_%w]+
	SKIP          <- %s+
]==]

local p = l.compile(grammar)

local parse = function(source, name)
	local ast, errlabel, errpos = p:match(source)

	if not ast then
		print(errlabel, errpos)
	end

	print(ast)
end

parse([[
	hello hi
]])
