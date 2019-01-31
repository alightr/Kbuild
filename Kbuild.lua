--[[
Linux-like Kbuild for tup.
--]]

built_in_o	= 'built-in.o'
lib_a		= 'lib.a'
depends_y	= _G['depends-y']
compiled_objects = {}

--[[
Retrieve dependencies of target.
--]]
function target_depends(target)
	return _G[target .. '-depends-y']
end

--[[
Retrieve group of target.
--]]
function target_group(target)
	return _G[target .. '-group-y']
end

--[[
Returns %true if @x is nil or empty.
--]]
function is_nil_or_empty(x)
	return x == nil or #x == 0
end

--[[
Retrieve textual representation of @x or empty string if @x is nil or empty.
--]]
function tostring_or_empty(x)
	if is_nil_or_empty(x) then
		return ''
	end
	return tostring(x)
end

--[[
Replace or add extension to file.
--]]
function with_ext(file, new_ext)
	local curr_ext = tup.ext(file)
	if not is_nil_or_empty(curr_ext) then
		file = file:sub(1, -(curr_ext:len() + 2))
	end
	if not is_nil_or_empty(new_ext) then
		file = file .. '.' .. new_ext
	end
	return file
end

--[[
Invoke @fn for each unique element of @src.

If @src is nil or empty, results in no-op.
--]]
function for_each_unique(fn, src)
	if is_nil_or_empty(src) then
		return
	end

	local hash = {}

	for k,v in ipairs(src) do
		if hash[v] == nil then
			hash[v] = 1
			fn(v)
		end
	end
end

function do_merge_strings(dst, src)
	if is_nil_or_empty(src) then
		return
	end

	if type(src) ~= 'table' then
		dst += tostring(src)
		return
	end

	for k,v in ipairs(src) do
		if v ~= nil then
			local str = tostring(v)
			if #str ~= 0 then
				dst += str
			end
		end
	end
end

--[[
Merge string or table @x with string or table @y into new table.
--]]
function merge_strings(x, y)
	local dst = {}

	do_merge_strings(dst, x)
	do_merge_strings(dst, y)

	if #dst == 0 then
		return nil
	end
	return dst
end

--[[
Emit command for source->target.
--]]
function cmd(source, depends, cmd, target, groups)
	local input = {}

	if source ~= nil then
		input += source
	end
	input.extra_inputs = merge_strings(depends, target_depends(target))

	tup.rule(input, cmd,
		 merge_strings(merge_strings(groups, target_group(target)),
			       target))
end

function cmd_cc_o(source, depends, target, groups)
	if compiled_objects[target] == 1 then
		return
	end

	cmd(source, depends, '!cmd_cc.o', target, groups)
end

function cmd_ar_a(source, depends, target, groups)
	cmd(source, depends, '!cmd_ar.a', target, groups)
end

function cmd_empty_o(target)
	cmd(nil, nil, '!cmd_empty.o', target, nil)
end

function cmd_ld_o(source, depends, target, groups)
	cmd(source, depends, '!cmd_ld.o', target, groups)
end

function cmd_xld_o(source, depends, target, groups)
	cmd(source, depends, '!cmd_xld.o', target, groups)
end

function cmd_ld_so(source, depends, target, groups)
	cmd(source, depends, '!cmd_ld.so', target, groups)
end

function cmd_ld_ex(source, depends, target, groups)
	cmd(source, depends, '!cmd_ld.ex', target, groups)
end

function process_objects(targets)
	local depends = merge_strings(depends_y, target_depends('obj'))
	local objs = {}

	for k,obj in ipairs(targets) do
		if obj:find('/', -1) then
			objs += obj .. built_in_o
		elseif obj:find('.a', -2) then
			objs += obj
		elseif not obj:find('.o', -2) then
			if obj ~= '' then
				error(string.format('Invalid object: %s', obj))
			end
		else
			local sub_y = _G[obj .. '-y']

			if is_nil_or_empty(sub_y) then
				cmd_cc_o(with_ext(obj, '[cS]'), depends,
					 obj, nil)
			else
				cmd_xld_o(process_objects(sub_y), depends,
					  obj, nil)
			end

			objs += obj
		end
	end
	return objs
end

for_each_unique(function(ex_cmd)
	local depends = merge_strings(depends_y, target_depends(ex_cmd))
	local group = target_group(ex_cmd)
	local y = _G[ex_cmd .. '-y']

	if is_nil_or_empty(y) then
		return
	end

	for k,target in ipairs(y) do
		local t_ext = tup.ext(target)
		local t_cmd = 'cmd_' .. ex_cmd .. '.' .. t_ext
		local s_ext = tostring_or_empty(_G[t_cmd .. '_source_ext'])
		local source = target:sub(1, -(t_ext:len() + 2)) .. s_ext

		cmd(source, depends, '!' .. t_cmd, target, group)
	end
end, _G['extra-y'])

do
	local obj_y = _G['obj-y']
	local objs = nil

	if obj_y ~= nil then
		objs = process_objects(obj_y)
	end

	if objs ~= nil and #objs ~= 0 then
		cmd_xld_o(objs, depends_y, built_in_o, nil)
	elseif not is_nil_or_empty(_G['obj-']) or
	       not is_nil_or_empty(_G['obj-n']) or
	       not is_nil_or_empty(_G['obj-m']) then
		cmd_empty_o(built_in_o)
	end
end

for_each_unique(function(source)
	if not source:find('.o', -2) then
		if source == '' then
			return
		end
		error(string.format('Invalid module target: %s', source))
	end

	local objs = process_objects({ source })
	if is_nil_or_empty(objs) then
		return
	end

	local ext = tostring_or_empty(_G['KBUILD_MODULE_EXT'])
	cmd(objs, merge_strings(depends_y, target_depends('mod')),
	    '!cmd_mod.' .. ext, with_ext(source, ext), target_group('mod'))
end, _G['obj-m'])

do
	local lib_y = _G['lib-y']
	local objs = nil

	if lib_y ~= nil then
		objs = process_objects(lib_y)
	end

	if objs ~= nil and #objs ~= 0 then
		cmd_ar_a(objs, merge_strings(depends_y, target_depends('lib')),
			 lib_a, target_group('lib'))
	elseif not is_nil_or_empty(_G['lib-']) or
	       not is_nil_or_empty(_G['lib-n']) then
		cmd_empty_o(lib_a)
	end
end

for_each_unique(function(target)
	if not target:find('.a', -2) then
		if source == '' then
			return
		end
		error(string.format('Invalid archive target: %s', target))
	end

	local objs = process_objects({ with_ext(target, 'o') })

	if objs ~= nil and #objs ~= 0 then
		cmd_ar_a(objs, merge_strings(depends_y, target_depends('ar')),
			 target, target_group('ar'))
	else
		cmd_empty_o(target)
	end
end, _G['ar-y'])

for_each_unique(function(target)
	if target:find('.so', -3) then
		cmd_ld_so(process_objects({ with_ext(target, 'o') }),
			  merge_strings(depends_y, target_depends('ld.so')),
			  target, target_group('ld.so'))
	elseif target:find('.o', -2) then
		cmd_ld_o(process_objects(_G[target .. '-y']),
			 merge_strings(depends_y, target_depends('ld.o')),
			 target, target_group('ld.o'))
	else
		cmd_ld_ex(process_objects({ target .. '.o' }),
			  merge_strings(depends_y, target_depends('ld.ex')),
			  target, target_group('ld.ex'))
	end
end, _G['ld-y'])
