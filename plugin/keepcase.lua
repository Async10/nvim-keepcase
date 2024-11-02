-- Return `new_word` with the case of `original_word'.
-- @param original_word The word which serves as the donor for the case
-- @param new_word The word whose case gets adapted
function keep_case(original_word, new_word)
    assert(type(original_word) == "string", "original_word has to be a string")
    assert(type(new_word)      == "string", "new_word has to be a string")

    if original_word:match("%l") == nil then        -- all upper case
        return string.upper(new_word)
    elseif original_word:match("%u") == nil then    -- all lower case
        return string.lower(new_word)
    end                                             -- mixed case

    local res = ""
    local original_word_len = string.len(original_word)
    local new_word_len = string.len(new_word)
    for i = 1, original_word_len do
        if i > new_word_len then
            break
        end

        local original_char = original_word:sub(i, i)
        local new_char = new_word:sub(i, i)
        if original_char:match("%u") then
            res = res .. new_char:upper()
        elseif original_char:match("%l") then
            res = res .. new_char:lower()
        else
            res = res .. new_char
        end
    end

    if new_word_len > original_word_len then
        res = res .. new_word:sub(original_word_len + 1)
    end

    return res
end

-- Replace characters with special meaning in substitute string.
-- @param sub The substitute string
-- @param sub The submatch function (optional)
-- @return The adapted substitute string
function sub_replace(sub, submatch)
    assert(type(sub) == "string", "sub has to be a string")

    submatch = submatch or vim.fn.submatch
    local str_buf = {}
    local idx = 1
    while idx <= string.len(sub) do
        if string.byte(sub, idx) == string.byte("\\") then
            local group_idx = string.byte(sub, idx+1) - string.byte("0")
            if 0 <= group_idx and group_idx <= 9 then
                table.insert(str_buf, table.getn(str_buf)+1, submatch(group_idx))
                idx = idx + 2
                goto continue
            end
        end

        table.insert(str_buf, table.getn(str_buf)+1, string.sub(sub, idx, idx))
        idx = idx + 1

        ::continue::
    end

    return table.concat(str_buf, "")
end

local SUBSTITUTE_CMD_FLAGS = "&cegiInp#lr"
local parse_args = function(args)
    local pat, sub, flags, count;

    local delim = args:sub(1, 1)
    if delim then
        pat = args:match(string.format("%s([^%s]*)", delim, delim))
        if pat then
            sub = args:match(
                string.format("%s[^%s]*%s([^%s]*)", delim, delim, delim, delim))
            if sub then
                flags, count = args:match(string.format("%s([%s]*)%%s*(%%d*)$", delim, SUBSTITUTE_CMD_FLAGS))
            end
        end
    end

    return delim, pat, sub, flags, count
end

local NO_PREVIEW = 0
local PREVIEW_AND_PREVIEW_WINDOW = 2
local replace = function(opts)
    local delim, pat, sub, flags, count = parse_args(opts.args)

    if not pat or not sub then
        vim.notify("Nothing to replace")
        return
    end

    sub = string.format("\\=luaeval('keep_case(_A[1], sub_replace(_A[2]))', [submatch(0), '%s'])", sub)
    local substitute_cmd = string.format(
        "%d,%ds/%s/%s/%s %s",
        opts.line1, opts.line2, pat, sub, flags or "", count or "")
    vim.cmd(vim.trim(substitute_cmd))
end

local replace_preview = function(opts, preview_ns, preview_buf)
    local _, pat, sub, _, _ = parse_args(opts.args)
    if not pat then
        return NO_PREVIEW    --  without a pattern, we can't do anything
    end

    local buf = vim.api.nvim_get_current_buf()
    local start = opts.line1 - 1    -- line indexing is zero based
    local end_ = opts.line2         -- the end is exclusive that is why we don't need to substract 1 here
    local strict_indexing = false
    local lines = vim.api.nvim_buf_get_lines(buf, start, end_, strict_indexing)

    vim.cmd("hi clear Whitespace")
    local preview_buf_line = 0
    local hl_group = "Substitute"
    for i, line in ipairs(lines) do
        local match_result = vim.fn.matchstrlist({ line }, pat, { submatches = true })[1]
        if match_result then    -- we found a match
            local match = match_result.text
            local col_start = match_result.byteidx
            local col_end = col_start + string.len(match)
            local submatch = function(idx)
                if idx == 0 then
                    return match
                else
                    return match_result.submatches[idx]
                end
            end

            -- highlight match in current buffer
            vim.api.nvim_buf_add_highlight(
                buf,
                preview_ns,
                hl_group,
                start + i - 1,
                col_start,
                col_end
            )

            if preview_buf then
                -- replace match with substitute string, if it was provided
                if sub then
                    match = keep_case(match, sub_replace(sub, submatch))
                end

                -- update and set line
                line = line:sub(1, col_start) .. match .. line:sub(col_end + 1)
                local prefix = string.format("|%3d| ", start + i)
                vim.api.nvim_buf_set_lines(
                    preview_buf,
                    preview_buf_line,
                    preview_buf_line,
                    strict_indexing,
                    { prefix .. line }
                )

                -- highlight match in preview window
                vim.api.nvim_buf_add_highlight(
                    preview_buf,
                    preview_ns,
                    hl_group,
                    preview_buf_line,
                    #prefix + col_start,
                    #prefix + col_start + #match
                )

                preview_buf_line = preview_buf_line + 1
            end
        end
    end

    return PREVIEW_AND_PREVIEW_WINDOW
end

local create_user_command_opts = {
    nargs = 1,
    range = true,
    addr = "lines",
    preview = replace_preview,
}

vim.api.nvim_create_user_command(
    "Replace",
    replace,
    vim.tbl_extend("force", create_user_command_opts, { force = true })
);
if vim.fn.exists(":R") ~= 2 then    -- no full match with existing command
    vim.api.nvim_create_user_command("R", replace, create_user_command_opts);
end
