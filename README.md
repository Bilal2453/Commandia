# Commandia
A complete and simple to use commands manager for the library Discordia

# TODOs
1. Documentations
2. Command cooldown
3. Commands Categories
4. Optional arguments with default values
5. Auto prompting for invalid arguments

# Features
- Commands hot-reloading (reload on changes)
- Plain command names and aliases
- Advanced arguments system
  * Supports powerful flag-style similar to CLI tools (with supporting for quotes)
  * Arguments types system
        - Basic types, string (default), number, boolean
        - Discord Objects (Member, User, Message, Role, Channel, Emoji)
        - Discordia Objects (Color, Time-TODO-, Date-TODO-)
        - Custom user-defined types in seperated files (supports hot-reloading)
        - Custom user-defined types as callbacks
  * Custom/default responses on invalid arguments
  * Customizable Reactions on invalid/valid arguments
  * Infinite arguments
- Permissions management system (that also supports custom permissions such as "guildOwner")
- Custom error handling with optional customizable reactions on command success/fail
- All possible responses are customizable and can be turned off/on
- All paths are customizable

# Simple example
Main File:
```lua
local discordia = require("discordia")
local client = discordia.Client()

local commandia = require("commandia")
local manager = commandia.Manager{
  client = client,
  prefix = "!",
}

client:run("Bot TOKEN") -- Replace TOKEN by your bot token
```

After running this code you will notice new directories, go to your `commands` folder and create a new file named `hello.command.lua`, and add the following code:
```lua
local function callback(self, msg)
  msg:reply("Oh Hello ".. msg.member.mentionString)
end

return function(manager)
  manager:createCommand('hello', callback)
end
```

Now when you send `!hello` your bot should respond with `Oh Hello @Name`
