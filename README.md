# lua-schema

Zod-style schema validation for Lua tables. Pure Lua 5.4, no dependencies.

```lua
local s = require("schema")

local UserSchema = s.table({
    name  = s.string():min(1):max(100),
    email = s.string():email(),
    age   = s.number():int():min(13):optional(),
    role  = s.enum({"admin", "user", "guest"}),
})

local ok, result, errors = s.safe_parse(UserSchema, {
    name  = "Alice",
    email = "alice@example.com",
    role  = "admin",
})

if ok then
    print(result.name)  -- Alice
else
    for _, e in ipairs(errors) do
        print(e.path .. ": " .. e.message)
    end
end
```

## Install

Copy `schema.lua` into your project. No build step, no dependencies.

```sh
curl -O https://raw.githubusercontent.com/wholovesalife/lua-schema/main/schema.lua
```

Or with LuaRocks (planned).

## API

### Primitives

```lua
s.string()    -- validates strings
s.number()    -- validates numbers (integer or float)
s.boolean()   -- validates booleans
s.any()       -- passes any value through
s.literal(v)  -- exact value match
```

### String methods

| Method | Description |
|--------|-------------|
| `:min(n)` | Minimum length |
| `:max(n)` | Maximum length |
| `:length(n)` | Exact length |
| `:pattern(pat)` | Lua pattern match |
| `:email()` | Basic email validation |
| `:url()` | Must start with http:// or https:// |
| `:trim()` | Transform: strip whitespace |
| `:lower()` | Transform: lowercase |
| `:upper()` | Transform: uppercase |

### Number methods

| Method | Description |
|--------|-------------|
| `:min(n)` | Must be >= n |
| `:max(n)` | Must be <= n |
| `:int()` | Must be an integer |
| `:positive()` | Must be > 0 |
| `:negative()` | Must be < 0 |
| `:nonnegative()` | Must be >= 0 |

### Composite types

#### `s.table(shape)`

Validates a Lua table with named fields:

```lua
local Schema = s.table({
    id   = s.number():int():positive(),
    name = s.string():min(1),
    bio  = s.string():optional(),
})
```

Methods on table schema:

| Method | Description |
|--------|-------------|
| `:strict()` | Reject unknown keys |
| `:extend(shape)` | Add/override fields |

#### `s.array(item_schema)`

```lua
local Tags = s.array(s.string()):min(1):max(10)
local Matrix = s.array(s.array(s.number()))
```

Array methods: `:min(n)`, `:max(n)`, `:nonempty()`

#### `s.enum(values)`

```lua
local Color = s.enum({"red", "green", "blue"})
```

#### `s.union(schemas)`

```lua
local IdOrName = s.union({ s.number():int(), s.string():min(1) })
```

### Modifiers

All validators support:

| Method | Description |
|--------|-------------|
| `:optional()` | Allow nil (skips validation) |
| `:nullable()` | Allow `schema.null` sentinel |
| `:message(msg)` | Override error message |

### Parse functions

#### `s.parse(schema, value)` — throws on error

```lua
local result = s.parse(UserSchema, input)
-- throws: "schema validation failed:\n  .email: invalid email..."
```

#### `s.safe_parse(schema, value)` — returns ok, result, errors

```lua
local ok, result, errors = s.safe_parse(UserSchema, input)
if not ok then
    for _, e in ipairs(errors) do
        -- e.path: string like ".user.email"
        -- e.message: human-readable description
    end
end
```

### Error format

Errors are tables with two fields:

```lua
{ path = ".user.email", message = "invalid email address" }
```

Nested paths are reported correctly:

```
.users[2].address.zip: zip must be 5 digits
```

### Custom error messages

```lua
s.string():min(8):message("password must be at least 8 characters")
```

### Transforms

Transforms run after validation succeeds:

```lua
local Schema = s.string():trim():lower()
s.parse(Schema, "  Hello  ")  -- returns "hello"
```

### Null handling

```lua
local Schema = s.string():nullable()
s.parse(Schema, schema.null)  -- OK
s.parse(Schema, nil)          -- error: required

local Schema2 = s.string():optional():nullable()
s.parse(Schema2, nil)         -- OK
s.parse(Schema2, schema.null) -- OK
```

## Examples

See `examples/user.lua` and `examples/config.lua` for complete examples.

```sh
lua examples/user.lua
lua examples/config.lua
lua schema_test.lua
```

## Planned

- `s.record(key_schema, value_schema)` — map-like tables
- `s.tuple({...})` — fixed-length arrays
- `s.refine(schema, fn)` — custom refinement functions
- `s.transform(schema, fn)` — standalone transform
- `s.intersection(a, b)` — merge two object schemas
- LuaRocks rockspec
