
meta =
{
    -- ID of your mod; Make sure this is unique!
    -- Will be used for identifying the mod in dependency lists
    -- Will be changed to workshop ID (ensuring uniqueness) when you upload the mod to the workshop
    id = "2208370349",

    -- Name of your mod; You may want this to be unique, but it's not absolutely necessary.
    -- This is an additional helper attribute for you to easily identify your mod in the Mods() list
    name = "IncreasingThreat",

    -- Title of your mod that will be displayed to players
    title = "Increasing Threat",

    -- Type of your mod, either "mod" or "factionpack"
    type = "mod",

    -- Description of your mod that will be displayed to players
    description = "This mod aims to increase the impact of pirate attacks over time. As you repel pirate attacks you will gradually accumulate Hatred, a stat specific to the local pirate faction, and Notoriety, a global stat that affects all pirates. As your Hatred and Notoriety increase, pirates will send stronger and stronger attacks into the sectors that you are currently in. If the pirates hate you enough, or if you are notorious enough, you may trigger a special type of attack along with the standard wave of enemies. This uses a number of ships from Extra Ship Classes Core.",

    -- Insert all authors into this list
    authors = {"KnifeHeart"},

    -- Version of your mod, should be in format 1.0.0 (major.minor.patch) or 1.0 (major.minor)
    -- This will be used to check for unmet dependencies or incompatibilities, and to check compatibility between clients and dedicated servers with mods.
    -- If a client with an unmatching major or minor mod version wants to log into a server, login is prohibited.
    -- Unmatching patch version still allows logging into a server. This works in both ways (server or client higher or lower version).
    version = "1.6.13",

    -- If your mod requires dependencies, enter them here. The game will check that all dependencies given here are met.
    -- Possible attributes:
    -- id: The ID of the other mod as stated in its modinfo.lua
    -- min, max, exact: version strings that will determine minimum, maximum or exact version required (exact is only syntactic sugar for min == max)
    -- optional: set to true if this mod is only an optional dependency (will only influence load order, not requirement checks)
    -- incompatible: set to true if your mod is incompatible with the other one
    -- Example:
    -- dependencies = {
    --      {id = "Avorion", min = "0.17", max = "0.21"}, -- we can only work with Avorion between versions 0.17 and 0.21
    --      {id = "SomeModLoader", min = "1.0", max = "2.0"}, -- we require SomeModLoader, and we need its version to be between 1.0 and 2.0
    --      {id = "AnotherMod", max = "2.0"}, -- we require AnotherMod, and we need its version to be 2.0 or lower
    --      {id = "IncompatibleMod", incompatible = true}, -- we're incompatible with IncompatibleMod, regardless of its version
    --      {id = "IncompatibleModB", exact = "2.0", incompatible = true}, -- we're incompatible with IncompatibleModB, but only exactly version 2.0
    --      {id = "OptionalMod", min = "0.2", optional = true}, -- we support OptionalMod optionally, starting at version 0.2
    -- },
    dependencies = {
        {id = "2207469437", min = "1.7.8"},
        {id = "Avorion", min = "2.2", max = "*.*"}
    },

    -- Set to true if the mod only has to run on the server. Clients will get notified that the mod is running on the server, but they won't download it to themselves
    serverSideOnly = false,

    -- Set to true if the mod only has to run on the client, such as UI mods
    clientSideOnly = false,

    -- Set to true if the mod changes the savegame in a potentially breaking way, as in it adds scripts or mechanics that get saved into database and no longer work once the mod gets disabled
    -- logically, if a mod is client-side only, it can't alter savegames, but Avorion doesn't check for that at the moment
    saveGameAltering = true,

    -- Contact info for other users to reach you in case they have questions
    contact = "",
}
