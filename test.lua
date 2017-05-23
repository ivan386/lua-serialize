require "serialize"


local table0 = {"self key", name_test = 1, }
table0.self = table0
table0[table0]={"oiewrhter"}
local table1={nil,nil,nil, recovery = 1, recovery0 = 2, recovery1 = 5, [{x = 1, "no linked table as key 1"}]={"nn1"},"test1", [table0] = table0}
local table2={table1,nil,nil,[{x = 2, "no linked table as key 2",table1}]={"nn2"},"test2"}
local table3={table1,table2,nil,[{x = 3, "no \\ \n linked table as key 3",table1,table2,[{"no linked table as key 3.1"}]="3.1"}]={"nn3"},"test3"}
table1[1]=table3
table1["numbers test"] = {0/0, -1/0, 1/0, 1234567890.1234567890, 1,2,3,4,5,6, 6.2 }
table1["boolean test"] = {true, false}
table1["string test"] = "\0\1\2\3\4\5\6\7\8\9\10\t\n\\"
table1["order test"] = {"1", "2", [5] = "5", "3 or 6?"}
table1["lng str"] = "too long string copy test."
table1["lng str copy"] = table1["lng str"]
table1[table1["lng str"]] = "lng str as key"
table1["function test"] = function() return "test" end
table1[table1["function test"]] = "function as key"
table1[table1]={[table1]={[table1]="multi key test"}}
table1[2]=table2
table1[3]=table2
table2[2]=table2
table2[3]=table3
table3[3]=table1
table1[table1]="table1.1"
table1[table2]="table1.2"
table1[table3]="table1.3"
table2[table1]=table1
table2[table2]=table2
table2[table3]=table3
table3[table1]=table1

--table1._G=_G

table3[ [=[


Multiline key test



]=] ] = "Multiline key test done"

	 
local seri = serialize(table1, true)
print(seri)
-- local file = io.open("D:\\xxx.txt","w")
-- file:write(seri)
for i=0,1000 do

	seri=serialize(assert(loadstring(seri))(), true)
	if i==0 then
		print(seri)
	end
end
io.stderr:write(seri)


--[[
local buf
function step_by_step(text)
	io.write(text)
	table.insert(buf, text)
	--io.read(1)
end

for i = 1, 1 do
	buf = {}
	step_by_step("return ")
	serialize(table1, step_by_step)
	f = io.open("rex.txt", "wb")
	f:write(table.concat(buf))
	f:close()
	local t, e = loadstring(table.concat(buf))
	print(e)
	table1 = t()
end]]


--[[
    return ({
            key1 = 1,
            key2 = 2,
            ...
            function recovery(self)

            end
        }):recovery()
]]