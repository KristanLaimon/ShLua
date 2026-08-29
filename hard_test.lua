--- @param table any
--- @param level? number
function Debug_PrintTable(table, level)
    level = level or 0

    if type(table) == "table" then
        io.write("{\n")
        for key, value in pairs(table) do
            io.write(string.rep("\t", level) .. string.format("[%s] = ", key))
            Debug_PrintTable(value, level)
            io.write(",\n")
        end
        io.write("}")
    else
        io.write(tostring(table))
    end
end

--- @param logicFunct fun(): nil
--- @param name? string
--- @return fun(): nil
function MeasureFunctionTime(logicFunct, name)
    name = name or ""
    return function()
        local _start = os.clock()
        logicFunct()
        local _end = os.clock()
        print(string.format("Function %s. Took: %.2f seconds", name, _end - _start))
    end
end

function Hola()
    print("Hello world")
    for i = 1, 1000, 1 do
        io.write(tostring(i) .. " ")
    end
end

local HolaWithLogs = MeasureFunctionTime(Hola, "Hola")
HolaWithLogs()
