--!nonstrict
-- Все настройки баланса игры в одном месте.
-- Меняй числа здесь — код трогать не нужно.

local Config = {}

-- Старт
Config.START_COINS = 30
Config.START_SPORES = { glow_blue = 3 }
Config.STUDIO_BONUS_COINS = 500 -- в Studio новый игрок получает +500 монет для тестов

-- Грядки
Config.TOTAL_BEDS = 8
Config.BED_COLS = 4 -- грядки стоят сеткой 4 x 2
Config.START_BEDS = 4
Config.BED_PRICES = { [5] = 100, [6] = 250, [7] = 600, [8] = 1500 }

-- Скрещивание и мутации
Config.CROSS_CHANCE = 0.4 -- шанс получить спору гибрида при сборе
Config.GOLD_CHANCE = 0.03 -- шанс, что посаженный гриб станет золотым

Config.MUTATIONS = {
	none = { name = "", mult = 1 },
	gold = { name = "Золотой", mult = 5 },
	storm = { name = "Грозовой", mult = 3 },
}

-- Кристальная гроза (событие на весь сервер)
Config.STORM_INTERVAL_MIN = 360 -- секунд между грозами (минимум)
Config.STORM_INTERVAL_MAX = 600
Config.STUDIO_FIRST_STORM = 45 -- в Studio первая гроза через 45 сек
Config.STORM_DURATION = 90
Config.STORM_TICK = 10 -- как часто во время грозы проверяются мутации
Config.STORM_MUTATION_CHANCE = 0.08
Config.STORM_SPECIES_CHANCE = 0.1 -- шанс получить спору Грозовика при сборе грозового гриба

-- Техническое
Config.STUDIO_SPEED = 5 -- в Studio грибы растут в 5 раз быстрее
Config.AUTOSAVE_INTERVAL = 120
Config.DATASTORE_NAME = "Svetogriby_v1"
Config.PLOT_COUNT = 6 -- пещер на сервере = максимум игроков

-- Звуки: вставь ID из Creator Store (0 = без звука)
Config.SOUNDS = {
	plant = 0,
	harvest = 0,
	sell = 0,
	discover = 0,
	unlock = 0,
	thunder = 0,
	click = 0,
	music = 0,
}

-- Соседние грядки (слева, справа, сверху, снизу)
function Config.neighbors(index: number): { number }
	local cols = Config.BED_COLS
	local row = (index - 1) // cols
	local col = (index - 1) % cols
	local out = {}
	if col > 0 then
		table.insert(out, index - 1)
	end
	if col < cols - 1 and index + 1 <= Config.TOTAL_BEDS then
		table.insert(out, index + 1)
	end
	if row > 0 then
		table.insert(out, index - cols)
	end
	if index + cols <= Config.TOTAL_BEDS then
		table.insert(out, index + cols)
	end
	return out
end

return Config
