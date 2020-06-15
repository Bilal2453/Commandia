  --[[lit-meta
  name = "Commandia"
  version = "0.0.1"
  dependencies = {}
  description = "A complete and simple to use commands manager for the library Discordia"
  tags = { "discordia", "commandia", "discord", "bot", "commands" }
  license = "MIT"
  author = { name = "Bilal2453" }
]]
return {
  Manager = require('./objects/Manager')
  VERSION = '0.0.1-ALPHA'
}