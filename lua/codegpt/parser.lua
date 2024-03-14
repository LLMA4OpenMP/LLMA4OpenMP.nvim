local ltreesitter = require("ltreesitter")
local c_parser = ltreesitter.require("c")

local Prompts = require("codegpt.prompts")

local Parser = {
	nested = false,
	private = false,
	reduction = false,
	update = false,
	conditional = false,
	indexx = "",
	errmsg = "This loop is not parallelizable!\n"
}
local experiences = ""

local par = false

local assigned = {
	name = {},
	index = {},
	depth = {}
}

local queried = {
	name = {},
	index = {},
	depth = {}
}

local reduction_count = {
	name = {},
	index = {},
	depth = {}
}

local no_reduction = {
	name = {},
	index = {},
	depth = {}
}

function Parser.check(text_selection)

	if string.find(text_selection, "printf") or string.find(text_selection, "scanf") then
		Parser.err("IO!")
		return false
	end

	local tree = c_parser:parse_string(text_selection)
	local head = tree:root():named_child(0)
	
	Parser.indexx = head:named_child(2):named_child(0):source()
    
	if head:named_child(3):name() == "compound_statement" then
		if Parser.compound_handle(head:named_child(3), 1) then
			if (not reduction) and #reduction_count["name"] ~= 0 then
				Parser.reduction = true
				experiences = experiences .. Prompts.reduction
			end
			if Parser.sub_check() then
				Parser.err("Dependency!")
				return false
			end
			if experiences == "" then experiences = [[No experience matched, maybe you should just apply "#pragma omp parallel for" to the loop.]] end
			if par then
				return experiences
			else
				Parser.err("Assignment only!")
				return false
			end
		else
			return false
		end
	else
		if Parser.statement_handle(head:named_child(3), 1) then
			if (not reduction) and #reduction_count["name"] ~= 0 then
				Parser.reduction = true
				experiences = experiences .. Prompts.reduction
			end
			if Parser.sub_check() then
				Parser.err("Dependency!")
				return false
			end
			if experiences == "" then experiences = [[No experience matched, maybe you should just apply "#pragma omp parallel for" to the loop.]] end
			if par then
				return experiences
			else
				Parser.err("Assignment only!")
				return false
			end
		else
			return false
		end
	end
end

function Parser.compound_handle(node, depth)
	local flag = true
    
	for i = 0, node:named_child_count() - 1 do
	   	local tmp = node:named_child(i)
	   	local name = tmp:name()
	   	
	   	if name == "expression_statement" then
			if tmp:named_child(0):name() == "assignment_expression" then
				if (tmp:named_child(0):named_child(0):name() == "identifier") and (string.find(tmp:source(), "+=") or string.find(tmp:source(), "-=") or string.find(tmp:source(), "*=") or string.find(tmp:source(), "/=")) then
					Parser.reduction = true
					experiences = experiences .. Prompts.reduction
				end
				flag = Parser.assign_handle(tmp:named_child(0), depth)
			elseif tmp:named_child(0):name() == "conditional_expression" then
				flag = Parser.condition_handle(tmp:named_child(0), depth)
			elseif tmp:named_child(0):name() == "call_expression" then
				flag = Parser.call_handle(tmp:named_child(0), depth)
			elseif tmp:named_child(0):name() == "update_expression" then
				flag = Parser.PnR(tmp:named_child(0):named_child(0):source(), tmp:named_child(0):named_child(0):source(), "null", "null")
				Parser.create(assigned, tmp:named_child(0):named_child(0):source(), "null", depth)
				Parser.create(queried, tmp:named_child(0):named_child(0):source(), "null", depth)
				if not update then
					Parser.update = true
					experiences = experiences .. Prompts.update
				end
			else
				Parser.err("Expression not found!")
				Parser.err(tmp:named_child(0):name())
				return false
			end
	   	elseif name == "for_statement" then
			if tmp:named_child(3):name() == "compound_statement" then
				flag = Parser.compound_handle(tmp:named_child(3), depth + 1)
			else
				flag = Parser.statement_handle(tmp:named_child(3), depth + 1)
			end
			if not Parser.nested then
				Parser.nested = true
				experiences = Prompts.nested .. experiences
			end
		elseif name == "if_statement" then
			flag = Parser.if_handle(tmp, depth)
		elseif name == "compound_statement" then
			flag = Parser.compound_handle(tmp, depth)
		elseif name == "switch_statement" then
			--pass
		elseif name == "declaration" then
			flag = Parser.dec_handle(tmp, depth)
		else
			Parser.err("Statement not found!")
			Parser.err(name)
			return false
	    end
	    	
		if not flag then
			break 
		end
	end
    
	return flag
end

function Parser.statement_handle(node, depth)
    local flag = true
	local tmp = node
    local name = tmp:name()

    if name == "expression_statement" then
		if tmp:named_child(0):name() == "assignment_expression" then
			if (tmp:named_child(0):named_child(0):name() == "identifier") and (string.find(tmp:source(), "+=") or string.find(tmp:source(), "-=") or string.find(tmp:source(), "*=") or string.find(tmp:source(), "/=")) then
				Parser.reduction = true
				experiences = experiences .. Prompts.reduction
			end
			flag = Parser.assign_handle(tmp:named_child(0), depth)
		elseif tmp:named_child(0):name() == "conditional_expression" then
			flag = Parser.condition_handle(tmp:named_child(0), depth)
		elseif tmp:named_child(0):name() == "call_expression" then
			flag = Parser.call_handle(tmp:named_child(0), depth)
		elseif tmp:named_child(0):name() == "update_expression" then
			flag = Parser.PnR(tmp:named_child(0):named_child(0):source(), tmp:named_child(0):named_child(0):source(), "null", "null")
			Parser.create(assigned, tmp:named_child(0):named_child(0):source(), "null", depth)
			Parser.create(queried, tmp:named_child(0):named_child(0):source(), "null", depth)
			if not update then
				Parser.update = true
				experiences = experiences .. Prompts.update
			end
		else
			Parser.err("Expression not found!")
			Parser.err(tmp:named_child(0):name())
			return false
		end
	elseif name == "for_statement" then
		if tmp:named_child(3):name() == "compound_statement" then
			flag = Parser.compound_handle(tmp:named_child(3), depth + 1)
		else
			flag = Parser.statement_handle(tmp:named_child(3), depth + 1)
		end
		if not Parser.nested then
			Parser.nested = true
			experiences = Prompts.nested .. experiences
		end
	elseif name == "if_statement" then
		flag = Parser.if_handle(tmp, depth)
	elseif name == "compound_statement" then
		flag = Parser.compound_handle(tmp, depth)
	elseif name == "switch_statement" then
			--pass
	elseif name == "declaration" then
		flag = Parser.dec_handle(tmp, depth)
	else
		Parser.err("Statement not found!")
		Parser.err(name)
		return false
	end
    
	return flag
end

function Parser.dec_handle(node, depth)
	for i = 0, node:named_child_count() - 1 do
		if node:named_child(i):name() == "init_declarator" then
			if node:named_child(i):named_child(0):name() ~= "identifier" then
				Parser.err("Declearation error!")
				return false
			else
				Parser.create(assigned, node:named_child(i):named_child(0):source(), "null", "null")
			end
		end
	end
	return true
end

function Parser.assign_handle(node, depth)
	local l_node = node:named_child(0)
	local r_node = node:named_child(1)
	local flag1 = true
	local flag2 = true
	
	while l_node:name() == "unary_expression" or l_node:name() == "parenthesized_expression" or l_node:name() == "cast_expression" or l_node:name() == "field_expression" do
		if l_node:name() == "cast_expression" then
			l_node = l_node:named_child(1)
		else
			l_node = l_node:named_child(0)
		end
	end	
	
	while r_node:name() == "unary_expression" or r_node:name() == "parenthesized_expression" or r_node:name() == "cast_expression" or r_node:name() == "field_expression" do
		if r_node:name() == "cast_expression" then
			r_node = r_node:named_child(1)
		else
			r_node = r_node:named_child(0)
		end
	end

	if l_node:name() == "identifier" then
		flag1 = Parser.PnR(l_node:source(), r_node:source(), "null", "null")
		Parser.create(assigned, l_node:source(), "null", depth)
	elseif l_node:name() == "subscript_expression" then
		local sub_table = {}
		Parser.get_sub(l_node, sub_table)

		for i = 2, #sub_table do
			if string.find(sub_table[i]:source(), "/") then
				Parser.err("Divide!")
				return false
			end

			if Parser.changed(sub_table[i], 1) then
				Parser.err("Indirect access!")
				return false
			end
		end

		flag1 = Parser.subscript_handle(l_node, depth, assigned)
	else
		Parser.err("Assignment type not found!")
		Parser.err(l_node:name())
		return false
	end
	
	if r_node:name() == "cast_expression" then
		r_node = r_node:named_child(1)
	end
	
	if r_node:name() == "unary_expression" then
		r_node = r_node:named_child(0)
	end

	if r_node:name() == "identifier" then
		Parser.create(queried, r_node:source(), "null", depth)
	elseif r_node:name() == "subscript_expression" then
		flag2 = Parser.subscript_handle(r_node, depth, queried)
	elseif r_node:name() == "binary_expression" then
		flag2 = Parser.binary_handle(r_node, depth)
	elseif r_node:name() == "number_literal" then
		-- pass
	elseif r_node:name() == "true" then
		-- pass
	elseif r_node:name() == "false" then
		-- pass
	elseif r_node:name() == "string_literal" then
		-- pass
	elseif r_node:name() == "char_literal" then
		-- pass
	elseif r_node:name() == "conditional_expression" then
		flag2 = Parser.condition_handle(r_node, depth)
	elseif r_node:name() == "call_expression" then
		flag2 = Parser.call_handle(r_node, depth)
	else
		Parser.err("Assignment type not found!")
		Parser.err(r_node:name())
		return false
	end
    
	return flag1 and flag2
end

function Parser.get_sub(node, sub_table)
	local l_node = node:named_child(0)
	local r_node = node:named_child(1)
	
	if l_node:name() == "subscript_expression" then
		Parser.get_sub(l_node, sub_table)
	else
		sub_table[#sub_table + 1] = l_node
	end
	
	sub_table[#sub_table + 1] = r_node
end

function Parser.subscript_handle(node, depth, table)
	local flag = true
	
	local sub_table = {}
	Parser.get_sub(node, sub_table)
	Parser.create(table, sub_table[1]:source(), sub_table, depth)
	
	for i = 2, #sub_table do
		if sub_table[i]:name() == "identifier" then
			Parser.create(queried, sub_table[i]:source(), "null", depth)
		elseif sub_table[i]:name() == "subscript_expression" then
			flag = Parser.subscript_handle(sub_table[i], depth, queried)
		elseif sub_table[i]:name() == "binary_expression" then
			flag = Parser.binary_handle(sub_table[i], depth)
		elseif sub_table[i]:name() == "number_literal" then
			-- pass
		else
			Parser.err("Subscript type not found!")
			Parser.err(sub_table[i]:name())
			return false
		end
		
		if not flag then
			break
		end
	end

	return flag
end

function Parser.binary_handle(node, depth)
	par = true
	local flag1 = true
	local flag2 = true
	local l_node = node:named_child(0)
	local r_node = node:named_child(1)
	
	while l_node:name() == "unary_expression" or l_node:name() == "parenthesized_expression" or l_node:name() == "cast_expression" or l_node:name() == "field_expression" do
		if l_node:name() == "cast_expression" then
			l_node = l_node:named_child(1)
		else
			l_node = l_node:named_child(0)
		end
	end
	
	while r_node:name() == "unary_expression" or r_node:name() == "parenthesized_expression" or r_node:name() == "cast_expression" or r_node:name() == "field_expression" do
		if r_node:name() == "cast_expression" then
			r_node = r_node:named_child(1)
		else
			r_node = r_node:named_child(0)
		end
	end
	
	if l_node:name() == "binary_expression" then
		flag1 = Parser.binary_handle(l_node, depth)
	elseif l_node:name() == "identifier" then
		Parser.create(queried, l_node:source(), "null", depth)
	elseif l_node:name() == "subscript_expression" then
		flag1 = Parser.subscript_handle(l_node, depth, queried)
	elseif l_node:name() == "number_literal" then
		--pass
	elseif l_node:name() == "string_literal" then
		-- pass
	elseif l_node:name() == "char_literal" then
		-- pass
	elseif l_node:name() == "false" then
		-- pass
	elseif l_node:name() == "true" then
		-- pass
	else
		Parser.err("Element not found!")
		Parser.err(l_node:name())
		return false
	end

	if r_node:name() == "binary_expression" then
		flag2 = Parser.binary_handle(r_node, depth)
	elseif r_node:name() == "identifier" then
		Parser.create(queried, r_node:source(), "null", depth)
	elseif r_node:name() == "subscript_expression" then
		flag2 = Parser.subscript_handle(r_node, depth, queried)
	elseif r_node:name() == "number_literal" then
		--pass
	elseif r_node:name() == "string_literal" then
		-- pass
	elseif r_node:name() == "char_literal" then
		-- pass
	elseif r_node:name() == "false" then
		-- pass
	elseif r_node:name() == "true" then
		-- pass
	else
		Parser.err("Element not found!")
		Parser.err(r_node:name())
		return false
	end

	return flag1 and flag2
end

function Parser.condition_handle(node, depth) -- pass
	local flag = true
	if not Parser.conditional then
		Parser.conditional = true
		experiences = experiences .. Prompts.conditional
	end
	return flag
end

function Parser.if_handle(node, depth)
	local flag1 = true
	local flag2 = true
	local flag3 = true
	flag1 = Parser.binary_handle(node:named_child(0):named_child(0))
	if node:named_child(1):name() == "compound_statement" then
		flag2 = Parser.compound_handle(node:named_child(1), depth)
	elseif node:named_child(1):name() == "expression_statement" then
		flag2 = Parser.statement_handle(node:named_child(1), depth)
	else
		flag2 = false
		Parser.err("if_flag2")
		Parser.err(node:named_child(1):name())
	end
	
	if node:named_child_count() > 2 then
		if node:named_child(2):named_child(0):name() == "if_statement" then
			flag3 = Parser.if_handle(node:named_child(2):named_child(0), depth)
		elseif node:named_child(2):named_child(0):name() == "compound_statement" then
			flag3 = Parser.compound_handle(node:named_child(2):named_child(0), depth)
		elseif node:named_child(2):named_child(0):name() == "expression_statement" then
			flag3 = Parser.statement_handle(node:named_child(2):named_child(0), depth)
		else
			flag3 = false
			Parser.err("if_flag3")
			Parser.err(node:named_child(2):named_child(0):name())
		end
	end
	return flag1 and flag2 and flag3
end

function Parser.call_handle(node, depth)
	par = true
	tmp = node:named_child(1)
	local flag = true
	for i = 0, tmp:named_child_count() - 1 do
		local nn = tmp:named_child(i)
		if nn:name() == "cast_expression" then
			nn = nn:named_child(1)
		end
		if nn:name() == "identifier" then
			Parser.create(queried, tmp:named_child(i):source(), "null", depth)
		elseif nn:name() == "subscript_expression" then
			flag = Parser.subscript_handle(tmp:named_child(i), depth, queried)
		elseif nn:name() == "binary_expression" then
			flag = Parser.binary_handle(tmp:named_child(i), depth)
		elseif nn:name() == "pointer_expression" then
			flag = false
			Parser.err("pointer inside call")
		elseif nn:name() == "number_literal" then
			-- pass
		else
			Parser.err("Argument type not found!")
			Parser.err("type: " .. tmp:named_child(i):name())
			Parser.err("name: " .. tmp:named_child(i):source())
			return false
		end
		
		if not flag then
			break
		end
	end
	return false
end


function Parser.create(table, name, index, depth)
	local place = #table["name"] + 1
	table["name"][place] = name
	table["index"][place] = index
	table["depth"][place] = depth
end

function Parser.find(table, name, index, depth)
	for i = 1, #table["name"] do
		if (table["name"][i] == name) and (table["index"][i] == index) then
			if (depth == "null") or (table["depth"][i] == depth) or (table["depth"][i] == "null")then
				return true
			end
		end
	end
	return false
end

function Parser.delete(name)
	for i = 1, #reduction_count["name"] do
		if reduction_count["name"][i] == name then
			table.remove(reduction_count["name"], i)
			table.remove(reduction_count["index"], i)
			table.remove(reduction_count["depth"], i)
			return true
		end
	end
	return false
end

function Parser.PnR(l_node, r_node, index, depth)
	if Parser.find(assigned, l_node, index, depth) then
		--pass
	elseif Parser.find(queried, l_node, index, depth) then
		Parser.err("Dependency!")
		return false
	else
		if not Parser.private then
			Parser.private = true
			experiences = experiences .. Prompts.private
		end
	end

	if not (Parser.find(no_reduction, l_node, "null", "null") or Parser.find(assigned, l_node, "null", "null")) then
		if string.match(r_node, l_node) then
			if Parser.delete(l_node) then
				Parser.create(no_reduction, l_node, "null", "null")
			else
				Parser.create(reduction_count, l_node, "null", "null")
			end
		end
	end
	return true
end

function Parser.binary_changed(node, depth)
	local l_node = node:named_child(0)
	local r_node = node:named_child(1)

	if Parser.changed(l_node, depth) or Parser.changed(r_node, depth) then
		return true
	else
		return false
	end
end

function Parser.changed(index, depth)
	local flag = false

	if (depth > 1) and (index:source() == Parser.indexx) then
		flag = true
	elseif index:name() == "identifier" then
		flag = Parser.find(assigned, index:source(), "null", "null")
	elseif index:name() == "subscript_expression" then
		local sub_table = {}
		Parser.get_sub(index, sub_table)
		if Parser.find(assigned, sub_table[1]:source(), sub_table, "null") then
			flag = true
		else
			for i = 2, #sub_table do
				flag = Parser.changed(sub_table[i], depth + 1)

				if flag then
					break
				end
			end
		end
	elseif index:name() == "binary_expression" then
		flag = Parser.binary_changed(index, depth)
	elseif index:name() == "number_literal" then
		flag = false
	else
		Parser.err("Subscript type not found!")
		flag = true
	end
	return flag
end

function Parser.test()
	for i = 1, #assigned["name"] do
		if assigned["index"][i] == "null" then
			print("variable: " .. assigned["name"][i])
		else
			io.write("variable: " .. assigned["name"][i])
			for j = 2, #assigned["index"][i] do
				io.write("[")
				io.write(assigned["index"][i][j]:source())
				io.write("]")
			end
			print("\n")
		end
	end
	
	print("-----------------------------------------------")
	
	for i = 1, #queried["name"] do
		if queried["index"][i] == "null" then
			print("variable: " .. queried["name"][i])
		else
			io.write("variable: " .. queried["name"][i])
			for j = 2, #queried["index"][i] do
				io.write("[")
				io.write(queried["index"][i][j]:source())
				io.write("]")
			end
			print("\n")
		end
	end

	print("-----------------------------------------------")

	if Parser.private then print("private") end
	if Parser.reduction then print("reduction") end
	if Parser.nested then print("nested") end
	if Parser.conditional then print("conditional") end
end

function Parser.err(str)
	Parser["errmsg"] = Parser["errmsg"] .. str .. "\n"
end

function Parser.init()
	Parser["nested"] = false
	Parser["private"] = false
	Parser["update"] = false
	Parser["reduction"] = false
	Parser["conditional"] = false
	Parser["indexx"] = ""
	Parser["errmsg"] = "This loop is not parallelizable!\n"
	
	experiences = Prompts.iter

	par = true

	assigned = {
		name = {},
		index = {},
		depth = {}
	}

	queried = {
		name = {},
		index = {},
		depth = {}
	}

	reduction_count = {
		name = {},
		index = {},
		depth = {}
	}

	no_reduction = {
		name = {},
		index = {},
		depth = {}
	}
end

function Parser.diff(A, B)
	local flag = false
	for i = 2, #A do
		if (A[i]:name() == "number_literal") and (B[i]:name() == "number_literal") and (A[i]:source() ~= B[i]:source()) then
			return false
		end

		if Parser.changed(A[i], 2) then
			if A[i]:source() ~= B[i]:source() then
				return true
			end
		else 
			if A[i]:source() == B[i]:source() then
				--flag = true
			end
		end
	end
	return flag
end

function Parser.sub_check()
	for i = 1, #assigned["name"] do
		if assigned["index"][i] ~= "null" then
			for j = 1, #queried["name"] do
				if (assigned["name"][i] == queried["name"][j]) and Parser.diff(assigned["index"][i], queried["index"][j]) then
					return true
				end
			end
		end
	end
	return false
end

return Parser
