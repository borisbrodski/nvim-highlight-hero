std = "lua51"
read_globals = { "vim" }
max_line_length = 120
exclude_files = { ".tests/" }

files["tests/"] = { std = "+busted" }
