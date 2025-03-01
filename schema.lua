-- schema.lua — basic type validators
local schema = {}

local function path_str(path)
    if #path == 0 then return "." end
    local parts = {}
    for _, p in ipairs(path) do
        parts[#parts + 1] = (type(p) == "number") and ("[" .. p .. "]") or ("." .. p)
    end
    return table.concat(parts)
end

local Validator = {}
Validator.__index = Validator

function Validator:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o._checks = o._checks or {}
    o._optional = false
    o._nullable = false
    o._custom_message = nil
    return o
end

function Validator:optional()
    local v = self:clone()
    v._optional = true
    return v
end

function Validator:nullable()
    local v = self:clone()
    v._nullable = true
    return v
end

function Validator:message(msg)
    local v = self:clone()
    v._custom_message = msg
    return v
end

function Validator:clone()
    local copy = {}
    for k, val in pairs(self) do copy[k] = val end
    copy._checks = {}
    for _, c in ipairs(self._checks) do copy._checks[#copy._checks + 1] = c end
    setmetatable(copy, getmetatable(self))
    return copy
end

function Validator:parse(value, path)
    path = path or {}
    if value == nil then
        if self._optional then return nil, nil end
        return nil, {{ path = path_str(path), message = self._custom_message or ("required value missing at path " .. path_str(path)) }}
    end
    local ok, err = self:_check_type(value, path)
    if not ok then return nil, {{ path = path_str(path), message = err }} end
    local errors = {}
    for _, check in ipairs(self._checks) do
        local valid, e = check(value, path)
        if not valid then errors[#errors + 1] = { path = path_str(path), message = e } end
    end
    if #errors > 0 then return nil, errors end
    return value, nil
end

function Validator:_check_type(value, path) _ = value; _ = path; return true, nil end

local StringValidator = Validator:new({ _type = "string" })
function StringValidator:_check_type(value, path)
    if type(value) ~= "string" then
        return false, "expected string, got " .. type(value) .. " at path " .. path_str(path)
    end
    return true, nil
end

local NumberValidator = Validator:new({ _type = "number" })
function NumberValidator:_check_type(value, path)
    if type(value) ~= "number" then
        return false, "expected number, got " .. type(value) .. " at path " .. path_str(path)
    end
    return true, nil
end

local BooleanValidator = Validator:new({ _type = "boolean" })
function BooleanValidator:_check_type(value, path)
    if type(value) ~= "boolean" then
        return false, "expected boolean, got " .. type(value) .. " at path " .. path_str(path)
    end
    return true, nil
end

function schema.string()
    local v = StringValidator:new(); setmetatable(v, StringValidator); StringValidator.__index = StringValidator; return v
end
function schema.number()
    local v = NumberValidator:new(); setmetatable(v, NumberValidator); NumberValidator.__index = NumberValidator; return v
end
function schema.boolean()
    local v = BooleanValidator:new(); setmetatable(v, BooleanValidator); BooleanValidator.__index = BooleanValidator; return v
end

local function push(path, key)
    local p = {}
    for _, v in ipairs(path) do p[#p + 1] = v end
    p[#p + 1] = key
    return p
end

local TableValidator = Validator:new({ _type = "table" })

function TableValidator:new(shape)
    local o = Validator.new(self, { _shape = shape or {} })
    return o
end

function TableValidator:_check_type(value, path)
    if type(value) ~= "table" then
        return false, "expected table, got " .. type(value) .. " at path " .. path_str(path)
    end
    return true, nil
end

function TableValidator:parse(value, path)
    path = path or {}
    if value == nil then
        if self._optional then return nil, nil end
        return nil, {{ path = path_str(path), message = "required value missing at path " .. path_str(path) }}
    end
    if type(value) ~= "table" then
        return nil, {{ path = path_str(path), message = "expected table, got " .. type(value) .. " at path " .. path_str(path) }}
    end
    local errors = {}
    local result = {}
    for key, field_schema in pairs(self._shape) do
        local parsed, errs = field_schema:parse(value[key], push(path, key))
        if errs then
            for _, e in ipairs(errs) do errors[#errors + 1] = e end
        else
            result[key] = parsed
        end
    end
    for key, val in pairs(value) do
        if self._shape[key] == nil then result[key] = val end
    end
    if #errors > 0 then return nil, errors end
    return result, nil
end

function schema.table(shape)
    local v = TableValidator:new(shape); setmetatable(v, TableValidator); TableValidator.__index = TableValidator; return v
end
schema.object = schema.table

return schema
