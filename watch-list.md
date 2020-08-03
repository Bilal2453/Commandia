### To-Test
* loader: The few new changes did not cause side-effects on some editors.

* Command: `:setName` method doesn't conflict when a command with the same new name already exist.

### To-Do
* *: Documentations.

* Command: Cooldowns.

* Command: local function `get` should return a key-value table when keep-false is enabled.

* Command: A new system for arguments, that offers:
  A) Flags -current is good-
  B) positioned arguments
  C) options?
  D) Categories

  Similar to [argparse](https://github.com/mpeterv/argparse), and think of a way for handling those from inside the command file.

* default-types: Add missing types, and planned ones
  - Time
  - Date
  - Deque (?)
  - GuildCategoryChannel (?)
  - Permissions
  - PermissionOverwrite (??)
  - Snowflake (??)
  - Stopwatch
  - Webhook (?)

* commandsHandler: Do not allow for `Command` to have no callback (it should always be either a global `callback` or a callback provided)

* commandsHandler: remove the `self` argument from the callback; or move it to the end of the arguments. Or maybe implement it somehow else?
(like env injecting, sounds like a bad idea though.)
  
* README: Better English, better `Features` explaining.

* README?: Add more examples.

* messagesHandler: a full re-write.

### Bugs
* *Missing Tests*.
