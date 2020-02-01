
function safe_string(value)
	if type(value) == "string" then
		local v = string.gsub(value, "([\\\10\13%c%z\"])([0-9]?)", function(chr, digit)
			local b = string.byte(chr)
			if #digit == 1 then
				if string.len(b) == 1 then return "\\00"..b..digit end
				if string.len(b) == 2 then return "\\0"..b..digit end
			end
			return "\\"..b..digit
		end)
		return '"'..v..'"'
	elseif type(value) == "number" then
		if not ((value > 0) or (value < 0) or (value == 0)) then -- indeterminate form
			return "0/0"
		elseif value == 1/0 then -- infinity
			return "1/0"
		elseif value == -1/0 then -- negative infinity
			return "-1/0"
		else
			return value
		end
	elseif type(value) == "function" then
		local ok, dump = pcall(string.dump, value)
		if ok then
			return "loadstring("..safe_string(dump)..")"
		end
	elseif type(value) == "boolean" then
		return tostring(value)
	elseif type(value) == "nil" then
		return "nil"
	end
	
	return "nil --[=[can't serialize; "..tostring(value).."]=]"
end

function safe_key(key)
	local safe_name = string.match(key, "^([A-Za-z_]+[A-Za-z0-9_]*)$")
	local keywords = {
        ["and"] = true,
        ["break"] = true,
        ["do"] = true,
        ["else"] = true,
        ["elseif"] = true,
        ["end"] = true,
        ["false"] = true,
        ["for"] = true,
        ["function"] = true,
        ["goto"] = true,
        ["if"] = true,
        ["in"] = true,
        ["local"] = true,
        ["nil"] = true,
        ["not"] = true,
        ["or"] = true,
        ["repeat"] = true,
        ["return"] = true,
        ["then"] = true,
        ["true"] = true,
        ["until"] = true,
        ["while"] = true
    }
	if safe_name and not keywords[safe_name] then
		return safe_name, "."
	end
	return "["..safe_string(key).."]", ""
end

local function testname(name)
	assert( (type(name) == "table")
			or (name:sub(1,1) == ".")
			or (name:sub(1,1) == "[")
			or (name:sub(1,4) == "root")
			or (name:sub(1,3) == "key")
	)
end
	
function serialize(value, name_or_bool_for_return, fnc_write,  skip)
    local buf
    if not fnc_write then
        buf = {};
        fnc_write = function(data)
            table.insert(buf, data)
        end
    end
	
	if ( type(name_or_bool_for_return) == "string" ) then
		fnc_write(name_or_bool_for_return)
		fnc_write(" = ")
	elseif ( type(name_or_bool_for_return) == "boolean" and name_or_bool_for_return == true ) then
		fnc_write("return ")
	end

	if type(value) == "table" then
		local obj_map = {}
		local keys = {order = {}, links = {}}
		local recover = {}
		local recovery_name = "recovery"
		local deep = 0
		

		
		local function add_key_value(tabl, key, value)
			local links = keys.links[key]
			if not links then
				table.insert(keys.order, key)
				links = {}
				keys.links[key] = links
			end
			table.insert(links, {tabl = tabl, value = value})
		end
		
		local serialize_table
		local function serialize_value(value, name, parent)
			if type(value) == "table" then
				serialize_table(value, name, parent)
			else
				fnc_write(safe_string(value))
				if (type(value) == "function") then
					obj_map[value] = {name = name , parent = parent}
				end
			end
		end	

		local function tbl_new_line(not_empty, deep)
			return string.format((not_empty and ",\n%s") or "\n%s", string.rep("\t", deep))
		end

		function serialize_table(tabl, name, parent, open)
			assert(obj_map[tabl] == nil)
			obj_map[tabl] = {name = name , parent = parent}
			testname(name)
			fnc_write("{")
			deep = deep + 1

			local not_empty
			local last_index
			
			for index, value in ipairs(tabl) do
				if obj_map[value] then
					break
				end
				if (not skip) or not skip(tabl, index, value) then
					fnc_write(tbl_new_line(not_empty, deep))
					serialize_value(value, string.format("[%i]", index), tabl)
					last_index = index
					not_empty = true
				end
			end
			
			for key, value in pairs(tabl) do
				if (not skip) or not skip(tabl, key, value) then
					if (type(key) == "table")
					or (type(key) == "function")
					then
						add_key_value(tabl, key, value)
					elseif (not last_index)
					or (type(key) ~= "number")
					or (key > last_index)
					or (key < 1)
					or (key > math.floor(key))
					then
						local name, dot = safe_key(key)
						testname(dot..name)
						if obj_map[value] then
							table.insert(recover, {tabl = tabl, name = dot..name, value = value})
						else
							fnc_write(string.format("%s%s=", tbl_new_line(not_empty, deep), name))
							serialize_value(value, dot..name, tabl)
							not_empty = true
						end
					end
				end
			end
			deep = deep - 1
			if not open then 
				if not_empty then
					fnc_write(string.format("\n%s}", string.rep("\t", deep))) 
				else
					fnc_write("}")
				end
			end
			return not_empty
		end
		
		local get_key, format_key
		
		function format_key(key)
			if obj_map[key] then
				return string.format("[%s]", get_key(key))
			else
				return key
			end
		end
		
		function get_key(obj)
			local key = {}
			local info = obj_map[obj]
			while info do
				table.insert(key, 1, format_key(info.name))
				info = obj_map[info.parent]
			end
			return table.concat(key)
		end
	
        fnc_write("(")
		
		if value[recovery_name] then
			local indx = 0
			local new_name
			repeat 
				new_name = recovery_name..indx
				indx = indx + 1
			until not value[new_name]
			recovery_name = new_name
		end
		
        local not_empty = serialize_table(value, "root", nil, true)
		
		-- recover links
        if next(keys.order) or next(recover) then
			deep = deep + 2
			local tabs = string.rep("\t", deep)
            fnc_write(string.format("%s%s=function(root)\n\t\troot.%s=nil;\n\t\tlocal key={};\n", 
				((not_empty and ",\n\t") or ""), recovery_name, recovery_name))
			local idx = 0
            while next(keys.order) do
                local keys_old = keys
                keys = {order = {}, links = {}}
                for _, key in ipairs(keys_old.order) do
					if not obj_map[key] then
						idx = idx + 1
						local key_name = string.format("key[%i]", idx)
						fnc_write(string.format("%s%s=", tabs, key_name))
						serialize_value(key, key_name)
						fnc_write(";\n")
					end
                    
                    for _, link in pairs(keys_old.links[key]) do
						if obj_map[link.value] then
							testname(key)
							table.insert(recover, {tabl = link.tabl, name = key, value = link.value})
						else
							fnc_write(string.format("%s%s[%s]=", tabs, get_key(link.tabl), get_key(key)))
							serialize_value(link.value, key, link.tabl)
							fnc_write(";\n")
						end
                    end
                end
            end
			
			for _, rec in ipairs(recover) do
				fnc_write(string.format("%s%s%s=%s;\n", tabs, get_key(rec.tabl), format_key(rec.name), get_key(rec.value)))
			end
            fnc_write(string.format("\t\treturn root;\n\tend\n}):%s()", recovery_name))
        else
            fnc_write("})")
        end
    else
        fnc_write(safe_string(value))
    end
    if ( buf ) then
        return table.concat(buf)
    end
end