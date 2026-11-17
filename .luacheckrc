std = "lua51"
-- `vim` is writable (we assign to vim.o.*, vim.bo.* etc.); declaring it under
-- globals rather than read_globals avoids "setting read-only field" warnings.
globals = { "vim" }
max_line_length = 120
-- scripts/demo/invoice.lua is sample code shown in the README demo, not plugin code.
exclude_files = { ".tests/", "scripts/demo/invoice.lua" }

files["tests/"] = { std = "+busted" }
