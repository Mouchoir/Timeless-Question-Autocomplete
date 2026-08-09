local _, ns = ...

--------------------------------------------------------------------------------
-- Text normalisation
--
-- Gossip options are matched on a normalised key rather than raw text, so
-- punctuation, casing, accents and UI escape sequences cannot break a match.
--   "Réservoir Glissecroc"  -> "reservoirglissecroc"
--   "Mur'ghouls"            -> "murghouls"
--------------------------------------------------------------------------------

local ACCENTS = {
	["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a",
	["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
	["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
	["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
	["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u",
	["ç"] = "c", ["ñ"] = "n", ["ý"] = "y", ["ÿ"] = "y",
	["œ"] = "oe", ["æ"] = "ae", ["ß"] = "ss",
	["À"] = "a", ["Á"] = "a", ["Â"] = "a", ["Ã"] = "a", ["Ä"] = "a", ["Å"] = "a",
	["È"] = "e", ["É"] = "e", ["Ê"] = "e", ["Ë"] = "e",
	["Ì"] = "i", ["Í"] = "i", ["Î"] = "i", ["Ï"] = "i",
	["Ò"] = "o", ["Ó"] = "o", ["Ô"] = "o", ["Õ"] = "o", ["Ö"] = "o",
	["Ù"] = "u", ["Ú"] = "u", ["Û"] = "u", ["Ü"] = "u",
	["Ç"] = "c", ["Ñ"] = "n", ["Ý"] = "y",
	["Œ"] = "oe", ["Æ"] = "ae",
}

-- Leading articles are dropped before matching: the frFR client presents each
-- option as prose ("Le Cercle cenarien.") where enUS uses the bare noun
-- ("Cenarion Circle"). Both sides go through this function, so stripping them
-- collapses the two forms onto the same key.
local ARTICLES = {
	["le"] = true, ["la"] = true, ["les"] = true,
	["un"] = true, ["une"] = true, ["des"] = true, ["du"] = true, ["de"] = true,
	["the"] = true, ["a"] = true, ["an"] = true,
}

function ns.Normalize(text)
	if type(text) ~= "string" then return nil end
	-- Strip UI escape sequences (colours, textures, atlases).
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	for from, to in pairs(ACCENTS) do
		text = text:gsub(from, to)
	end
	text = text:lower():gsub("\226\128\153", "'") -- typographic apostrophe

	local changed = true
	while changed do
		changed = false
		text = text:gsub("^%s+", "")
		local elided = text:match("^[ld]'(.+)$") -- l'Archidruide, d'Aggra
		if elided then
			text, changed = elided, true
		else
			local first, rest = text:match("^(%a+)%s+(.+)$")
			if first and ARTICLES[first] then
				text, changed = rest, true
			end
		end
	end

	-- Drop everything that is not a plain letter or digit.
	text = text:gsub("[^a-z0-9]", "")
	if text == "" then return nil end
	return text
end

--------------------------------------------------------------------------------
-- Answer database
--
-- One entry per question. `correct` holds every spelling of the right answer
-- across supported locales, `wrong` holds the decoys. Only the option *text*
-- matters, never the question text or the option order, so a question is
-- recognised as long as one of its four options is known.
--
-- No correct answer is ever used as a decoy in another question, which is what
-- makes the flat lookup below safe.
--
-- frFR notes: proper nouns that Blizzard leaves untranslated are covered by the
-- enUS string alone. A handful of translated answers are still missing (marked
-- TODO) - the learning pass in Core.lua fills those in on its own.
--------------------------------------------------------------------------------

local QUESTIONS = {
	{ -- Horde ship crafted by goblins, destroyed by the Alliance
		correct = { "Draka's Fury", "Fureur de Draka" },
		wrong   = { "Hellscream's Fury", "Aggra's Fury", "Durotan's Fury" },
	},
	{ -- Undead murlocs
		correct = { "Mur'ghouls", "Mur'goules", "Mur'goule", "Mur'ghoules" },
		wrong   = { "Gorlocs", "Wolvar", "Mur'liches" },
	},
	{ -- Tirion Fordring's gray stallion
		correct = { "Mirador" },
		wrong   = { "Ashanor", "Mistsilver", "Feonir" },
	},
	{ -- Varian Wrynn's first wife
		-- The client spells it "Ellerian"; the Wowhead comment said "Ellerlan".
		correct = { "Tiffin Ellerian Wrynn", "Tiffin Ellerlan Wrynn" },
		wrong   = { "Tiffin Windemere Wrynn", "Therese Anne Wrynn", "Therese Angharad Wrynn" },
	},
	{ -- First satyr
		correct = { "Xavius" },
		wrong   = { "Peroth'arn", "Garaxxas", "Vyletongue" },
	},
	{ -- Ripsnarl's wife
		correct = { "Calissa Harrington" },
		wrong   = { "Emma Harrington", "Vanessa Whitehall", "Katrina Whitehall" },
	},
	{ -- Naga structure in Zangarmarsh
		-- frFR is "Réservoir de Glissecroc"; the "de" sits mid-string, so it
		-- survives article stripping and has to be spelled out here.
		correct = { "Coilfang Reservoir", "Réservoir de Glissecroc", "Réservoir Glissecroc" },
		wrong   = {
			"Snakecoil Cavern", "Serpentine Basin", "Spiralfang Cistern",
			-- frFR harvested
			"La caverne des Anneaux du serpent", "Le bassin Serpentin",
			"La citerne du Croc spiraloïde",
		},
	},
	{ -- Loa known as "Night's Friend"
		correct = { "Mueh'zala" },
		wrong   = { "Shirvallah", "Kimbul", "Shadra" },
	},
	{ -- Scarlet Crusade defender who slew Beltheris -- frFR harvested
		correct = { "Holia Sunshield", "Holia Soltarge" },
		wrong   = {
			"Fellari Swiftarrow", "Yana Bloodspear", "Valea Twinblades",
			"Fellari Viveflèche", "Yana Lance-de-Sang", "Valea Jumelames",
		},
	},
	{ -- Brown-skinned orcs
		correct = { "Mag'har" },
		wrong   = { "Felblood", "Mok'Nathal", "Fel orc" },
	},
	{ -- Succubus species
		correct = { "Sayaad" },
		wrong   = { "Ered'ruin", "Shivarra", "Eredar" },
	},
	{ -- Tilloa's younger brother
		correct = { "Giles" },
		wrong   = { "Billy", "William", "Tobias" },
	},
	{ -- Proto-dragon turned into Razorscale
		correct = { "Veranus" },
		wrong   = { "Galakrond", "Zeptek", "Vyletongue" },
	},
	{ -- Horde emissary who found Silvermoon too bright and clean
		-- frFR harvested: the client spells it Tataï.
		correct = { "Tatal", "Tataï" },
		wrong   = { "Cheneta", "Kristine Denny", "Dela Runetotem", "Dela Totem-Runique" },
	},
	{ -- Queen who oversaw the Gilnean evacuation
		correct = { "Queen Mia Greymane", "Reine Mia Grisetête" },
		wrong   = { "Queen Lia Greymane", "Queen Malia Greymane", "Queen Liria Greymane" },
	},
	{ -- Frail Zandalari troll slain on the Isle of Giants
		correct = { "Talak" },
		wrong   = { "Maaka", "Grimath", "Ra'wiri" },
	},
	{ -- Death knight floating citadel
		correct = { "Acherus" },
		wrong   = { "Naxxanar", "Kolramas", "Naxxramas" },
	},
	{ -- Orc clan that rode white wolves
		correct = { "Frostwolf clan", "Clan Loup-de-givre" },
		wrong   = { "Whiteclaw clan", "Warsong clan", "Icefang clan" },
	},
	{ -- lar'korwi in Taur-ahe -- frFR harvested
		correct = { "Sharp claw", "Griffe aiguisée" },
		wrong   = {
			"Razor tooth", "Sharp tooth", "Razor claw",
			"Griffe rasoir", "Dent rasoir", "Dent tranchante",
		},
	},
	{ -- Ethereal homeworld
		correct = { "K'aresh" },
		wrong   = { "Xarodi", "Khu'ral", "Xoroth" },
	},
	{ -- First death knight on Azeroth
		-- frFR harvested
		correct = { "Teron Gorefiend", "Teron Fielsang" },
		wrong   = {
			"Arthas Menethil", "Alexandros Mograine", "Koltira Deathweaver",
			"Koltira Tissemort",
		},
	},
	{ -- Icecrown gate the Horde attacked the Alliance at
		correct = { "Mord'rethar" },
		wrong   = { "Corp'rethar", "Aldur'thar", "Angrathar" },
	},
	{ -- Evidence that drove Arthas to purge Stratholme
		-- frFR harvested
		correct = { "Tainted grain", "Du grain pestiféré" },
		wrong   = {
			"Tainted soil", "Tainted wildlife", "Tainted water",
			"De la terre maculée", "Des créatures sauvages corrompues",
			"De l'eau contaminée",
		},
	},
	{ -- Leader of the gnomes
		-- frFR harvested
		correct = { "Gelbin Mekkatorque", "Gelbin Mekkanivelle" },
		wrong   = {
			"Millhouse Manastorm", "Sicco Thermaplugg", "Fizzcrank Fullthrottle",
			"Milhouse Tempête-de-Mana", "Psiko Thermojoncteur", "Spumelevier Pleingaz",
		},
	},
	{ -- Druidic organisation founded by Malfurion
		correct = { "Cenarion Circle", "Cercle cénarien" },
		wrong   = {
			"Crimson Ring", "Emerald Circle", "Earthen Ring",
			"Le Cercle cramoisi", -- observed in the frFR client
		},
	},
	{ -- Draenei joke about "Exodar" in naaru -- frFR harvested
		correct = { "Defective elekk turd", "Fiente d'elekk anormale" },
		wrong   = {
			"Crystal death trap", "Worthless elekk dung", "Radioactive biohazard",
			"Piège mortel de cristal", "Bouse d'elekk futile",
			"Danger biologique radioactif",
		},
	},
	{ -- Kurdran Wildhammer's gryphon
		-- frFR harvested: localised to Ciel'ree, contrary to the assumption that
		-- an apostrophised name is always left alone.
		correct = { "Sky'ree", "Ciel'ree" },
		wrong   = {
			"Swiftwing", "Sharpbeak", "Stormbeak",
			"Aile-Vive", "Bec-tranchant", "Foudrebec",
		},
	},
	{ -- Sindragosa's dragonflight
		correct = { "Blue dragonflight", "Vol bleu", "Vol draconique bleu" },
		wrong   = {
			"Red dragonflight", "Green dragonflight", "Bronze dragonflight",
			-- "Le Vol draconique rouge" observed in the frFR client; the other
			-- two follow the same pattern, which covers this one by elimination.
			"Vol draconique rouge", "Vol draconique vert", "Vol draconique bronze",
		},
	},
	{ -- Legendary ram in the Ironforge library -- frFR harvested
		correct = { "Toothgnasher", "Grincedents" },
		wrong   = {
			"Gorehoof", "Bloodhorn", "Steelmauler",
			"Tripesabot", "Cornesang", "Martelacier",
		},
	},
	{ -- Titan lore-keeper of the Pantheon
		correct = { "Norgannon" },
		wrong   = { "Aman'Thul", "Eonar", "Khaz'goroth" },
	},
	{ -- Aspects' gift to the night elves after the War of the Ancients
		correct = { "Nordrassil" },
		wrong   = { "Teldrassil", "Well of Eternity", "Moonwells" },
	},
	{ -- Broken draenei paladin turned shaman
		correct = { "Nobundo" },
		wrong   = { "Velen", "Akama", "Maraad" },
	},
	{ -- Obsidian Sanctum drakes
		-- frFR harvested: Shadron is localised to Obscuron.
		correct = { "Tenebron, Vesperon and Shadron", "Ténébron, Vespéron et Obscuron" },
		wrong   = {
			"Tenebron, Vesperon and Halion", "Theralion, Shadron and Abyssion",
			"Theralion, Halion and Abyssion",
			"Ténébron, Vespéron et Halion", "Theralion, Obscuron et Abyssion",
			"Theralion, Halion et Abyssion",
		},
	},
	{ -- "Thank you" in Draconic
		correct = { "Belan shi" },
		wrong   = { "Borela mir", "Avral shi", "Alena mir" },
	},
	{ -- Orc plague before the first Horde
		correct = { "Red pox", "Variole rouge", "Vérole rouge", "Peste rouge", "Fièvre rouge" },
		wrong   = { "Scarlet fever", "Blood pox", "Crimson fever" },
	},
	{ -- Highest druid rank
		correct = { "Archdruid", "Archidruide" },
		wrong   = { "Shaman", "Stormcaller", "Far seer" },
	},
	{ -- "May the bloodied crown stay lost and forgotten"
		correct = { "King Terenas Menethil II", "Roi Terenas Menethil II" },
		wrong   = { "Prince Arthas Menethil", "King Llane Wrynn", "Uther the Lightbringer" },
	},
}

--------------------------------------------------------------------------------
-- Correct answers by gossip option id
--
-- The server assigns each question a block of four consecutive option ids, in
-- display order, and sends the same ids to every client whatever its language.
-- Verified: 11 question blocks captured in both enUS and frFR came back
-- byte-identical, and no option id changed across 320 openings.
--
-- So this table is the primary lookup: it answers correctly in locales that
-- have never been harvested, including ones nobody here can read. The text
-- tables below stay as the fallback for the day Blizzard reshuffles the ids.
--------------------------------------------------------------------------------

ns.CORRECT_IDS = {
	[130908] = true, -- Mur'ghouls
	[130913] = true, -- Frostwolf clan
	[130917] = true, -- Archdruid
	[130919] = true, -- Gelbin Mekkatorque
	[130926] = true, -- Cenarion Circle
	[130927] = true, -- Mag'har
	[130932] = true, -- Blue dragonflight
	[130937] = true, -- Coilfang Reservoir
	[130973] = true, -- Nordrassil
	[130978] = true, -- Tainted grain
	[130979] = true, -- Acherus
	[130985] = true, -- Sky'ree
	[130990] = true, -- Queen Mia Greymane
	[130992] = true, -- Calissa Harrington
	[130995] = true, -- Teron Gorefiend
	[131002] = true, -- Nobundo
	[131003] = true, -- Tenebron, Vesperon and Shadron
	[131011] = true, -- Draka's Fury
	[131016] = true, -- Norgannon
	[131020] = true, -- Veranus
	[131023] = true, -- Defective elekk turd
	[131030] = true, -- King Terenas Menethil II
	[131033] = true, -- Xavius
	[131038] = true, -- Tiffin Ellerian Wrynn
	[131039] = true, -- K'aresh
	[131046] = true, -- Red pox
	[131048] = true, -- Holia Sunshield
	[131052] = true, -- Toothgnasher
	[131058] = true, -- Mord'rethar
	[131060] = true, -- Belan shi
	[131065] = true, -- Giles
	[131069] = true, -- Talak
	[131073] = true, -- Tatal
	[131076] = true, -- Sayaad
	[131081] = true, -- Mueh'zala
	[131083] = true, -- Sharp claw

	-- Inferred, not observed: 131007-131010 is the only remaining gap of exactly
	-- four, and Mirador is the only question whose ids were never captured. Its
	-- answer sits 4th in display order, hence 131010. Being wrong costs one wrong
	-- answer, after which the id is blacklisted and a fresh question is offered.
	[131010] = true, -- Mirador (inferred)
}

ns.ANSWER_ID_COUNT = 0
for _ in pairs(ns.CORRECT_IDS) do
	ns.ANSWER_ID_COUNT = ns.ANSWER_ID_COUNT + 1
end

ns.QUESTION_COUNT = #QUESTIONS
ns.CORRECT = {}
ns.WRONG = {}

for _, question in ipairs(QUESTIONS) do
	for _, text in ipairs(question.correct) do
		local key = ns.Normalize(text)
		if key then ns.CORRECT[key] = true end
	end
end

for _, question in ipairs(QUESTIONS) do
	for _, text in ipairs(question.wrong) do
		local key = ns.Normalize(text)
		-- A known answer always wins, so a typo in the decoy list cannot hide it.
		if key and not ns.CORRECT[key] then ns.WRONG[key] = true end
	end
end
