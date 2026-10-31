--!nonstrict
-- Рецепты скрещивания: два взрослых гриба на соседних грядках -> шанс получить спору нового вида.
-- Порядок в паре не важен.

local Recipes = {}

Recipes.list = {
	{ "glow_blue", "glow_sun", "glow_mint" },
	{ "glow_blue", "glow_ember", "glow_violet" },
	{ "glow_moss", "glow_blue", "glow_frost" },
	{ "glow_moss", "glow_sun", "glow_honey" },
	{ "glow_sun", "glow_ember", "glow_flame" },
	{ "glow_moss", "glow_ember", "glow_toxic" },
	{ "glow_flame", "glow_frost", "glow_steam" },
	{ "glow_violet", "glow_mint", "glow_dream" },
	{ "glow_toxic", "glow_honey", "glow_jelly" },
	{ "glow_dream", "glow_steam", "glow_rainbow" },
}

local map = {}

local function key(a: string, b: string): string
	if a < b then
		return a .. "+" .. b
	end
	return b .. "+" .. a
end

for _, r in Recipes.list do
	map[key(r[1], r[2])] = r[3]
end

-- Возвращает id гибрида или nil
function Recipes.find(a: string?, b: string?): string?
	if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" or a == b then
		return nil
	end
	return map[key(a, b)]
end

return Recipes
