Config = Config or {}

Config.ToolName = 'M7MD-tool'

Config.QBCorePerms = {
    'god',
    'admin',
    'operator',
    'staff',
    'supervisor',
    'trusted',
    'trial',
    'mod',
    'support',
}


Config.AllowAceCommand = true

Config.RequireQBCorePermission = true

Config.MaxGiveAmount = 1000
Config.GiveCooldownMs = 800
Config.MaxRemoveAmount = 1000
Config.RemoveCooldownMs = 800

Config.ClearInventoryCooldownMs = 1500

Config.MaxGiveMoney = 500000
Config.GiveMoneyCooldownMs = 800

Config.TeleportCooldownMs = 800

Config.EnableDebugOverlay = true
Config.EnableCopyStreetName = true
Config.EnableCopyPlayerInfo = true

Config.MetadataAllowedKeys = {}

Config.EnableSlashlessCommands = true
Config.SlashlessCooldownMs = 250
Config.SlashlessCommands = {
    'admin',
    'car',
    'dv',
}

Config.EnableEventTester = false
Config.EventTesterMaxPayloadBytes = 2048
Config.EventTesterAllowedEvents = {
}


