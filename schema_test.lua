-- schema_test.lua — test suite for schema.lua
local s = require("schema")

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS  " .. name)
    else
        failed = failed + 1
        print("  FAIL  " .. name)
        print("        " .. tostring(err))
    end
end

local function assert_ok(val, errors)
    if errors then
        local msgs = {}
        for _, e in ipairs(errors) do msgs[#msgs + 1] = e.message end
        error("expected success but got errors: " .. table.concat(msgs, "; "))
    end
    return val
end

local function assert_err(val, errors, pattern)
    _ = val
    if not errors then error("expected validation error but got success") end
    if pattern then
        local msgs = {}
        for _, e in ipairs(errors) do msgs[#msgs + 1] = e.message end
        local combined = table.concat(msgs, " | ")
        if not combined:find(pattern) then
            error("expected error matching '" .. pattern .. "', got: " .. combined)
        end
    end
end

print("=== String tests ===")

test("string accepts string", function()
    local v, errs = s.string():parse("hello")
    assert_ok(v, errs)
    assert(v == "hello")
end)

test("string rejects number", function()
    local v, errs = s.string():parse(42)
    assert_err(v, errs, "expected string")
end)

test("string:min passes", function()
    local v, errs = s.string():min(3):parse("hello")
    assert_ok(v, errs)
end)

test("string:min fails", function()
    local v, errs = s.string():min(10):parse("hi")
    assert_err(v, errs, "too short")
end)

test("string:max passes", function()
    local v, errs = s.string():max(10):parse("hello")
    assert_ok(v, errs)
end)

test("string:max fails", function()
    local v, errs = s.string():max(3):parse("toolong")
    assert_err(v, errs, "too long")
end)

test("string:pattern passes", function()
    local v, errs = s.string():pattern("^%d+$"):parse("12345")
    assert_ok(v, errs)
end)

test("string:pattern fails", function()
    local v, errs = s.string():pattern("^%d+$"):parse("abc")
    assert_err(v, errs, "pattern")
end)

test("string:email passes", function()
    local v, errs = s.string():email():parse("user@example.com")
    assert_ok(v, errs)
end)

test("string:email fails", function()
    local v, errs = s.string():email():parse("notanemail")
    assert_err(v, errs)
end)

test("string:trim transform", function()
    local v, errs = s.string():trim():parse("  hello  ")
    assert_ok(v, errs)
    assert(v == "hello", "expected 'hello', got '" .. tostring(v) .. "'")
end)

test("string:lower transform", function()
    local v, errs = s.string():lower():parse("HELLO")
    assert_ok(v, errs)
    assert(v == "hello")
end)

test("string optional nil passes", function()
    local v, errs = s.string():optional():parse(nil)
    assert(errs == nil, "expected no errors")
    assert(v == nil)
end)

test("string required nil fails", function()
    local v, errs = s.string():parse(nil)
    assert_err(v, errs, "required")
end)

print("\n=== Number tests ===")

test("number accepts number", function()
    local v, errs = s.number():parse(42)
    assert_ok(v, errs)
    assert(v == 42)
end)

test("number rejects string", function()
    local v, errs = s.number():parse("42")
    assert_err(v, errs, "expected number")
end)

test("number:min passes", function()
    local v, errs = s.number():min(0):parse(5)
    assert_ok(v, errs)
end)

test("number:min fails", function()
    local v, errs = s.number():min(10):parse(5)
    assert_err(v, errs, "too small")
end)

test("number:max passes", function()
    local v, errs = s.number():max(100):parse(50)
    assert_ok(v, errs)
end)

test("number:max fails", function()
    local v, errs = s.number():max(10):parse(100)
    assert_err(v, errs, "too large")
end)

test("number:int passes on integer", function()
    local v, errs = s.number():int():parse(5)
    assert_ok(v, errs)
end)

test("number:int fails on float", function()
    local v, errs = s.number():int():parse(3.14)
    assert_err(v, errs, "integer")
end)

test("number:positive passes", function()
    local v, errs = s.number():positive():parse(1)
    assert_ok(v, errs)
end)

test("number:positive fails on zero", function()
    local v, errs = s.number():positive():parse(0)
    assert_err(v, errs, "positive")
end)

print("\n=== Boolean tests ===")

test("boolean accepts true", function()
    local v, errs = s.boolean():parse(true)
    assert_ok(v, errs)
    assert(v == true)
end)

test("boolean accepts false", function()
    local v, errs = s.boolean():parse(false)
    assert_ok(v, errs)
    assert(v == false)
end)

test("boolean rejects string", function()
    local v, errs = s.boolean():parse("true")
    assert_err(v, errs, "expected boolean")
end)

print("\n=== Table/object tests ===")

test("table validates shape", function()
    local UserSchema = s.table({
        name = s.string(),
        age  = s.number():int():min(0),
    })
    local v, errs = UserSchema:parse({ name = "Alice", age = 30 })
    assert_ok(v, errs)
    assert(v.name == "Alice")
    assert(v.age == 30)
end)

test("table fails on missing required field", function()
    local UserSchema = s.table({ name = s.string(), age = s.number() })
    local v, errs = UserSchema:parse({ name = "Alice" })
    assert_err(v, errs, "age")
end)

test("table optional field passes when absent", function()
    local UserSchema = s.table({ name = s.string(), bio = s.string():optional() })
    local v, errs = UserSchema:parse({ name = "Alice" })
    assert_ok(v, errs)
end)

test("table nested schema", function()
    local AddrSchema = s.table({ city = s.string(), zip = s.string() })
    local UserSchema = s.table({ name = s.string(), address = AddrSchema })
    local v, errs = UserSchema:parse({ name = "Bob", address = { city = "NYC", zip = "10001" } })
    assert_ok(v, errs)
    assert(v.address.city == "NYC")
end)

test("table strict mode rejects extra keys", function()
    local Schema = s.table({ name = s.string() }):strict()
    local v, errs = Schema:parse({ name = "Alice", extra = "oops" })
    assert_err(v, errs, "unexpected key")
end)

test("table passes through extra keys in non-strict mode", function()
    local Schema = s.table({ name = s.string() })
    local v, errs = Schema:parse({ name = "Alice", extra = "ok" })
    assert_ok(v, errs)
    assert(v.extra == "ok")
end)

print("\n=== Array tests ===")

test("array validates items", function()
    local Schema = s.array(s.string())
    local v, errs = Schema:parse({ "a", "b", "c" })
    assert_ok(v, errs)
    assert(#v == 3)
end)

test("array fails when item invalid", function()
    local Schema = s.array(s.number())
    local v, errs = Schema:parse({ 1, 2, "three" })
    assert_err(v, errs, "expected number")
end)

test("array:min passes", function()
    local v, errs = s.array(s.number()):min(2):parse({ 1, 2, 3 })
    assert_ok(v, errs)
end)

test("array:min fails", function()
    local v, errs = s.array(s.number()):min(5):parse({ 1, 2 })
    assert_err(v, errs, "too short")
end)

test("array:nonempty fails on empty", function()
    local v, errs = s.array(s.string()):nonempty():parse({})
    assert_err(v, errs)
end)

test("array without item schema accepts any", function()
    local v, errs = s.array():parse({ 1, "two", true })
    assert_ok(v, errs)
end)

print("\n=== Enum tests ===")

test("enum accepts valid value", function()
    local Schema = s.enum({ "admin", "user", "guest" })
    local v, errs = Schema:parse("admin")
    assert_ok(v, errs)
    assert(v == "admin")
end)

test("enum rejects invalid value", function()
    local Schema = s.enum({ "admin", "user", "guest" })
    local v, errs = Schema:parse("superuser")
    assert_err(v, errs, "one of")
end)

print("\n=== Union tests ===")

test("union accepts first matching type", function()
    local Schema = s.union({ s.string(), s.number() })
    local v, errs = Schema:parse("hello")
    assert_ok(v, errs)
    assert(v == "hello")
end)

test("union accepts second matching type", function()
    local Schema = s.union({ s.string(), s.number() })
    local v, errs = Schema:parse(42)
    assert_ok(v, errs)
    assert(v == 42)
end)

test("union fails when no type matches", function()
    local Schema = s.union({ s.string(), s.number() })
    local v, errs = Schema:parse(true)
    assert_err(v, errs)
end)

print("\n=== Literal tests ===")

test("literal accepts exact value", function()
    local v, errs = s.literal("hello"):parse("hello")
    assert_ok(v, errs)
end)

test("literal rejects different value", function()
    local v, errs = s.literal("hello"):parse("world")
    assert_err(v, errs, "literal")
end)

print("\n=== Custom message tests ===")

test("custom message on string type error", function()
    local v, errs = s.string():message("name must be a string"):parse(42)
    assert_err(v, errs, "name must be a string")
end)

print("\n=== schema.parse (throw) ===")

test("schema.parse returns value on success", function()
    local v = s.parse(s.string(), "hello")
    assert(v == "hello")
end)

test("schema.parse throws on failure", function()
    local ok, err = pcall(function()
        s.parse(s.string(), 42)
    end)
    assert(not ok, "expected error to be thrown")
    assert(err:find("validation failed"), "expected 'validation failed' in: " .. err)
end)

print("\n=== schema.safe_parse ===")

test("safe_parse returns ok=true on success", function()
    local ok, val = s.safe_parse(s.number(), 42)
    assert(ok == true)
    assert(val == 42)
end)

test("safe_parse returns ok=false on failure", function()
    local ok, val, errs = s.safe_parse(s.number(), "not a number")
    assert(ok == false)
    assert(val == nil)
    assert(errs ~= nil)
end)

-- ─── Summary ──────────────────────────────────────────────────────────────────

print("\n" .. string.rep("─", 40))
print(string.format("  %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end

test("nested optional field absent passes", function()
    local Schema = s.table({ meta = s.table({ tags = s.array(s.string()):optional() }) })
    local v, errs = Schema:parse({ meta = {} })
    assert_ok(v, errs)
end)

test("enum required nil fails", function()
    local Schema = s.enum({ "a", "b", "c" })
    local v, errs = Schema:parse(nil)
    assert_err(v, errs, "required")
end)

test("union optional passes nil", function()
    local Schema = s.union({ s.string(), s.number() }):optional()
    local v, errs = Schema:parse(nil)
    assert(errs == nil)
end)

test("literal rejects wrong type entirely", function()
    local v, errs = s.literal(42):parse("42")
    assert_err(v, errs, "literal")
end)
