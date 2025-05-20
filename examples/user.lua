-- examples/user.lua — validate a user object
local s = require("schema")

local RoleSchema = s.enum({ "admin", "editor", "viewer" })

local AddressSchema = s.table({
    street = s.string():min(1),
    city   = s.string():min(1),
    zip    = s.string():pattern("^%d%d%d%d%d$"):message("zip must be 5 digits"),
    country = s.string():optional(),
})

local UserSchema = s.table({
    id       = s.number():int():positive(),
    username = s.string():min(3):max(32):pattern("^[%w_%-]+$"):message("username: only letters, numbers, _ and - allowed"),
    email    = s.string():email(),
    role     = RoleSchema,
    age      = s.number():int():min(13):max(120):optional(),
    address  = AddressSchema:optional(),
    tags     = s.array(s.string()):optional(),
    active   = s.boolean(),
})

-- Valid user
local ok_data = {
    id       = 1,
    username = "alice_dev",
    email    = "alice@example.com",
    role     = "admin",
    age      = 28,
    active   = true,
    address  = {
        street  = "123 Main St",
        city    = "Springfield",
        zip     = "62701",
        country = "US",
    },
    tags = { "developer", "oss" },
}

print("--- Valid user ---")
local ok, result, errors = s.safe_parse(UserSchema, ok_data)
if ok then
    print("OK: " .. result.username .. " <" .. result.email .. "> role=" .. result.role)
else
    for _, e in ipairs(errors) do
        print("ERROR at " .. e.path .. ": " .. e.message)
    end
end

-- Invalid user
local bad_data = {
    id       = -5,          -- must be positive
    username = "a b",       -- spaces not allowed
    email    = "notanemail",
    role     = "superadmin", -- not in enum
    active   = "yes",       -- must be boolean
}

print("\n--- Invalid user (expect errors) ---")
local ok2, _, errors2 = s.safe_parse(UserSchema, bad_data)
if not ok2 then
    for _, e in ipairs(errors2) do
        print("  [" .. e.path .. "] " .. e.message)
    end
end
