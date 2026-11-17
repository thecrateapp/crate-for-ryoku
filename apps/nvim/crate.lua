-- crate-for-ryoku: neovim
-- Crate's sober syntax over Ryoku's tokyonight (whose on_colors follows the
-- palette): cyan for keywords and functions, the light cyan for strings and
-- types, amber only for numbers, constants and escapes, faint italic comments
-- and docstrings, text tones for the rest. Laid down by `crate-for-ryoku
-- install`, removed by uninstall; delete the first line to keep it as yours.
local function crate(hl)
  -- accent #06b6d4, accent_hi #67e8f9, warning #fbbf24, text #f1f5f9, and
  -- text at 62 % and 42 % made solid over the #0a0a0f canvas
  local groups = {
    Comment = { fg = "#6b6d71", italic = true },
    ["@comment"] = { fg = "#6b6d71", italic = true },
    ["@string.documentation"] = { fg = "#6b6d71", italic = true },
    Keyword = { fg = "#06b6d4" },
    Statement = { fg = "#06b6d4" },
    Conditional = { fg = "#06b6d4" },
    Repeat = { fg = "#06b6d4" },
    Include = { fg = "#06b6d4" },
    ["@keyword"] = { fg = "#06b6d4" },
    ["@keyword.import"] = { fg = "#06b6d4" },
    ["@keyword.function"] = { fg = "#06b6d4" },
    ["@keyword.return"] = { fg = "#06b6d4" },
    ["@keyword.operator"] = { fg = "#06b6d4" },
    Function = { fg = "#06b6d4" },
    ["@function"] = { fg = "#06b6d4" },
    ["@function.call"] = { fg = "#06b6d4" },
    ["@function.method"] = { fg = "#06b6d4" },
    ["@function.builtin"] = { fg = "#06b6d4" },
    String = { fg = "#67e8f9" },
    ["@string"] = { fg = "#67e8f9" },
    Type = { fg = "#67e8f9" },
    ["@type"] = { fg = "#67e8f9" },
    ["@type.builtin"] = { fg = "#67e8f9" },
    ["@constructor"] = { fg = "#67e8f9" },
    Number = { fg = "#fbbf24" },
    Boolean = { fg = "#fbbf24" },
    Constant = { fg = "#fbbf24" },
    ["@number"] = { fg = "#fbbf24" },
    ["@boolean"] = { fg = "#fbbf24" },
    ["@constant"] = { fg = "#fbbf24" },
    ["@constant.builtin"] = { fg = "#fbbf24" },
    ["@string.escape"] = { fg = "#fbbf24" },
    ["@string.regexp"] = { fg = "#fbbf24" },
    Identifier = { fg = "#f1f5f9" },
    ["@variable"] = { fg = "#f1f5f9" },
    ["@variable.member"] = { fg = "#f1f5f9" },
    ["@variable.parameter"] = { fg = "#f1f5f9" },
    ["@property"] = { fg = "#f1f5f9" },
    ["@variable.builtin"] = { fg = "#06b6d4" },
    Operator = { fg = "#999ca0" },
    Delimiter = { fg = "#999ca0" },
    ["@operator"] = { fg = "#999ca0" },
    ["@punctuation.delimiter"] = { fg = "#999ca0" },
    ["@punctuation.bracket"] = { fg = "#999ca0" },
    ["@punctuation.special"] = { fg = "#999ca0" },
  }
  for name, spec in pairs(groups) do
    hl[name] = spec
  end
end

return {
  {
    "folke/tokyonight.nvim",
    opts = function(_, opts)
      local before = opts.on_highlights
      opts.on_highlights = function(hl, c)
        if before then
          before(hl, c)
        end
        crate(hl)
      end
    end,
  },
}
