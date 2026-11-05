std = "lua51"
-- `vim` is writable (we assign to vim.o.*, vim.bo.* etc.); declaring it under
-- globals rather than read_globals avoids "setting read-only field" warnings.
globals = { "vim" }
max_line_length = 120
exclude_files = { ".tests/" }

files["tests/"] = { std = "+busted" }
