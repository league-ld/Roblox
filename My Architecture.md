# My Architecture

#### This file contains the general overview of how I structure my games.

## Data Loading

The first step is the data loading. I will use the example from Stained Mists since it uses Maaster and Slot data, making it more complex. When the player joins, they are assigned a data folder, which
will be assigned to game.ServerStorage.Data[player.Name] at the end of the process. 

And for anyone arguing that folder/value-based data storage is not as performant as table-based, I ran the benchmarks
instancing 15000 NumberValues into the folder, which used 80-200ms and around 500kb of memory, which is insignificant even for such an overkill.

After the Master data is loaded, the slot field is checked and the corresponding slot data is loaded. Of course, if at any point this process fails, the player is kicked and his folder destroyed. Once all the data is received, it is ran through the mutations logic iteratively through each data version(this means that if the data structure was updated, the developer can write logic to update old players' data, and if the player skips many data updates, it will apply that logic one version at a time for predictable results), and then is loaded into the folder using a simple DFS algorithm. It is also important to mention that the data is loaded according to the default template folder, meaning updates to the data structure will erase old data and default the new entries. Also, folders have "Additive" attribute option, allowing them to ignore the template folder and load the data straight from the data received from the DataStore. Then the folder is parented to the game.ServerStorage.Data under player.Name for easy access over the game. The folder approach also makes reading and changing the data in testing much easier. Default values and new entries are also easy to make, but table-based data has the same benefits.

***

## PlayerHandler

One of the most important scripts in the game is PlayerHandler. It has 2 primary goals: Initialize and Update. It listens to each player being added, then waits for their data folder to appear to make sure they have loaded. Then it initializes all player variables. It then starts the updateCharacter function:

```luau
if player.Character then
  updateCharacter(player.Character)
end
player.CharacterAdded:Connect(updateCharacter)
```

First of all this clears connections using clearConnections() function. This ensures there are no dangling updates. Each update runs through bindConnect(event, func) unless needed otherwise. I do not destinguish player update events from character update events lifetimes unless needed otherwise, since this way is less prone to error.

```luau
local function clearConnections()
  for _, v in pairs(connections) do
    v:Disconnect()
  end
  table.clear(connections)
end

local function bindConnect(event, func)
  table.insert(connections, event:Connect(func))
end
```

Running every connection through bindConnect means that everything is handled nicely over character respawns.

The updateCharacter function runs all the inits and bindConnects to properly initialize everything relevant to the character and player.

***

## After

From this point forth, it depends on the specific game. I would usually also have LocalManager to be the center of the important client-sided events, but that too is game-specific. I also utilize my [Personal Techniques](https://github.com/league-ld/Roblox/blob/main/Personal%20Techniques.md) to make the game as scalable as possible. The general idea is to keep systems as separate as possible, so that one system failing keeps the rest from failing as well. I keep ModuleScripts in 4 folders: Modules, Lists, Classes and Functions. Functions are single function modules that I use a lot, like deepCopy or fetchData. Modules are shared code to be accessed from different scripts(StatsHandler, AppearanceLoader, etc.). Classes are the OOP classes. Lists(or I sometimes call them Configs) are tables of data(and often functions) that hold data that may change in the game's development(weapons, skills, dialogues, etc.)

***

## Classes

Most of my classes have a similar logic: they have DefaultValues(which are loaded directly into the main instance table on init), DefaultArgs(which are fallbacks if the main args parameter doesn't include a needed value), DefaultVar(sometimes needed, when a class needs private variables), and other per-class specific files needed. It practically always has an explicit :Destroy() to clean up everything, and set up the Use-After-Free warning from [Personal Techniques](https://github.com/league-ld/Roblox/blob/main/Personal%20Techniques.md).

***

## Results

Over the years working with and refining the architecture, I must say I am very satisfied with it. I am not saying this just to paint a better picture of myself, but I would genuinely recommend this to other devs. My games are scalable and very easy to add to because of the architecture. There are rarely any hiccups, and if there are, its usually on a smaller scale related to a single system. I will continue using this, as it has prooven itself amazing.
