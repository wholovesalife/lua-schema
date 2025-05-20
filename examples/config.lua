-- examples/config.lua — validate an application config
local s = require("schema")

local LogLevel = s.enum({ "debug", "info", "warn", "error" })

local DatabaseSchema = s.table({
    host     = s.string():min(1),
    port     = s.number():int():min(1):max(65535),
    name     = s.string():min(1),
    user     = s.string():min(1),
    password = s.string(),
    pool_min = s.number():int():nonnegative():optional(),
    pool_max = s.number():int():positive():optional(),
    ssl      = s.boolean():optional(),
})

local CacheSchema = s.table({
    enabled = s.boolean(),
    ttl     = s.number():int():positive(),
    backend = s.enum({ "memory", "redis", "memcached" }),
    url     = s.string():url():optional(),
}):optional()

local ServerSchema = s.table({
    host         = s.string(),
    port         = s.number():int():min(1):max(65535),
    workers      = s.number():int():positive():optional(),
    read_timeout = s.number():positive():optional(),
    cors_origins = s.array(s.string()):optional(),
})

local AppConfigSchema = s.table({
    env       = s.enum({ "development", "staging", "production" }),
    debug     = s.boolean():optional(),
    log_level = LogLevel,
    server    = ServerSchema,
    database  = DatabaseSchema,
    cache     = CacheSchema,
    secret_key = s.string():min(32):message("secret_key must be at least 32 characters"),
    allowed_hosts = s.array(s.string()):nonempty(),
})

-- Valid config
local config = {
    env       = "production",
    debug     = false,
    log_level = "info",
    server = {
        host    = "0.0.0.0",
        port    = 8080,
        workers = 4,
        cors_origins = { "https://app.example.com", "https://www.example.com" },
    },
    database = {
        host     = "db.internal",
        port     = 5432,
        name     = "myapp",
        user     = "app",
        password = "s3cr3t",
        pool_min = 2,
        pool_max = 10,
        ssl      = true,
    },
    cache = {
        enabled = true,
        ttl     = 300,
        backend = "redis",
        url     = "redis://cache.internal:6379",
    },
    secret_key    = "supersecretkeywithenoughcharactershere",
    allowed_hosts = { "example.com", "www.example.com" },
}

print("--- Valid config ---")
local ok, result, errors = s.safe_parse(AppConfigSchema, config)
if ok then
    print(string.format("OK: env=%s log=%s server=%s:%d db=%s:%d",
        result.env, result.log_level,
        result.server.host, result.server.port,
        result.database.host, result.database.port))
else
    for _, e in ipairs(errors) do
        print("ERROR [" .. e.path .. "]: " .. e.message)
    end
end

-- Invalid config
local bad_config = {
    env       = "local",         -- not in enum
    log_level = "verbose",       -- not in enum
    server = {
        host = "",               -- too short
        port = 99999,            -- out of range
    },
    database = {
        host     = "db",
        port     = 0,            -- too small
        name     = "myapp",
        user     = "app",
        password = "pw",
    },
    secret_key    = "short",     -- too short
    allowed_hosts = {},          -- nonempty fails
}

print("\n--- Invalid config (expect errors) ---")
local ok2, _, errors2 = s.safe_parse(AppConfigSchema, bad_config)
if not ok2 then
    for _, e in ipairs(errors2) do
        print("  [" .. e.path .. "] " .. e.message)
    end
end
