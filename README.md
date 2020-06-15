# Commandia
A complete and simple to use commands manager for the library Discordia

# TODOs
1. Documentations
2. Command's cooldowns
3. Commands Categories

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
