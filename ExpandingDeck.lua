--- Expanding Deck
--- Joker slots equal the current Ante (minimum 1).
--- Other slot bonuses (Antimatter, Negatives, Cryptid effects) stack on top:
--- the deck only ever adds or removes the difference when the Ante changes.

SMODS.Atlas({
    key = "expanding_deck",
    path = "expanding_deck.png",
    px = 71,
    py = 95,
})

local DECK_KEY = "b_expdeck_expanding"

local function is_active()
    return G.GAME
        and G.GAME.selected_back
        and G.GAME.selected_back.effect
        and G.GAME.selected_back.effect.center
        and G.GAME.selected_back.effect.center.key == DECK_KEY
end

local function current_ante()
    local ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1
    -- Talisman can turn numbers into big-number tables
    if type(ante) == "table" and to_number then
        ante = to_number(ante)
    end
    return math.floor(tonumber(ante) or 1)
end

local function change_joker_slots(delta)
    if delta == 0 then return end
    -- Newer Steamodded has a card limit API; fall back to the vanilla field otherwise
    if G.jokers.change_size then
        G.jokers:change_size(delta)
    else
        G.jokers.config.card_limit = G.jokers.config.card_limit + delta
    end
end

--- Bring joker slots in line with the current Ante.
--- G.GAME.expdeck_slots remembers how many slots the deck itself is providing.
local function sync_slots()
    if not (is_active() and G.jokers) then return end
    local target = math.max(1, current_ante())
    local applied = G.GAME.expdeck_slots or 1
    if target ~= applied then
        change_joker_slots(target - applied)
        G.GAME.expdeck_slots = target
    end
end

SMODS.Back({
    key = "expanding",
    atlas = "expanding_deck",
    pos = { x = 0, y = 0 },
    -- Vanilla starts with 5 slots; -4 leaves 1 at Ante 1 (stacks with anything else that changes the start)
    config = { joker_slot = -4 },
    loc_txt = {
        name = "Expanding Deck",
        text = {
            "{C:attention}Joker{} slots equal",
            "the current {C:attention}Ante{}",
            "{C:inactive}(Currently {C:attention}#1#{C:inactive} slots)",
        },
    },
    loc_vars = function(self, info_queue, back)
        local slots = 1
        if G.STAGE == G.STAGES.RUN and G.jokers then
            slots = G.jokers.config.card_limit
        end
        return { vars = { slots } }
    end,
    apply = function(self, back)
        G.GAME.expdeck_slots = 1
    end,
    -- Safety net in case something changes the Ante without going through ease_ante
    calculate = function(self, back, context)
        if context.setting_blind or context.starting_shop then
            sync_slots()
        end
    end,
})

-- Main trigger: run after the game's own Ante change event has finished
local ease_ante_ref = ease_ante
function ease_ante(mod)
    local ret = ease_ante_ref(mod)
    G.E_MANAGER:add_event(Event({
        trigger = "immediate",
        func = function()
            sync_slots()
            return true
        end,
    }))
    return ret
end
