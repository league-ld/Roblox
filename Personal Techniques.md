# Proxy Object
A Proxy Object(POB) is an abstraction layer which accepts an instance handle, and creates a POB class representing it. This technique, for example, allows me to 
create a streamlined system for players and NPCs, so I can access their data or properties without worrying whether I am dealing with a player or an NPC character. This also reduces
overall code size, since I don't have to make different versions of code depending on whether I'm dealing with an NPC or a player.

# Instance-wide singleton
Instance-wide singletons are singletons in scope of a given instance — similar to an entity-component system. What this means is that I can call Class.new() for an instance and only ever have
one instance of that class. For example, I use this in an AnimationHandler, where I can do AnimationHandler.new(character) multiple times, but only create one object which will then be reused.
Previously mentioned POB is also an instance-wide singleton.

# Memory Leak Warnings
Practically all classes have a Destroy() function which lets us clean them up after we're done using them. The problem is, if a class instance is referenced in any script, it will now point to an
empty table, which can cause many errors if left unnoticed. This is a common error in low level languages like C/C++ called "Use after free" or "Dangling pointer." In order to help catch such errors,
once the Destroy() is called on an instance and the table is wiped of all values, I attach a metatable to a now empty class instance, which will send a warning with debug traceback if the table is accessed(read or write).
This can also be routed through a telemetry function which sends the error to some server, where it can be inspected by the developers. This way errors can be caught by using the game's players as playtesters.


***

**__Note:__** Even if these techniques aren't necessarily new, they are techniques I have developed myself over time to fix issues and obstacles I had encountered.
