#!/usr/bin/env python3
"""Record the README demo GIFs.

Drives a real Neovim (`nvim --embed -u scripts/demo/init.lua`, only this
plugin loaded) over RPC, feeds it the keys of each scenario, renders the
screen Neovim sends back (ext_linegrid UI events) with Pillow and writes one
GIF per scenario into assets/. No terminal, screen recorder or GUI needed, and
the result is reproducible.

    pip install pynvim pillow
    python3 scripts/demo/record.py            # all demos
    python3 scripts/demo/record.py merge      # just one

Environment: NVIM (binary, default "nvim"), DEMO_FONT / DEMO_FONT_BOLD (paths
to a monospace TTF; default DejaVu Sans Mono).
"""
import os
import sys
import time

import pynvim
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets")

FONT = os.environ.get("DEMO_FONT", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")
FONT_BOLD = os.environ.get("DEMO_FONT_BOLD", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf")
FONT_SIZE = 17
PAD = 14  # around the text grid
CAPTION_H = 54
CAPTION_BG = (30, 33, 41)
CAPTION_FG = (224, 226, 234)
CHIP_BG = (72, 78, 94)
CHIP_FG = (255, 255, 255)


def rgb(n):
    return ((n >> 16) & 255, (n >> 8) & 255, n & 255)


class Screen:
    """The grid Neovim draws, kept up to date from `redraw` notifications."""

    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.grid = [[(" ", 0)] * cols for _ in range(rows)]
        self.hl = {0: {}}
        self.fg, self.bg = (224, 226, 234), (20, 22, 27)
        self.cursor = (0, 0)
        self.mode = "normal"
        self.font = ImageFont.truetype(FONT, FONT_SIZE)
        self.bold = ImageFont.truetype(FONT_BOLD, FONT_SIZE)
        self.small = ImageFont.truetype(FONT, 15)
        self.small_bold = ImageFont.truetype(FONT_BOLD, 15)
        self.cw = round(self.font.getlength("M"))
        ascent, descent = self.font.getmetrics()
        self.ch = ascent + descent + 3

    # -- UI events ------------------------------------------------------
    def apply(self, events):
        for ev in events:
            name, calls = ev[0], ev[1:]
            fn = getattr(self, "ev_" + name, None)
            if fn:
                for args in calls:
                    fn(*args)

    def ev_default_colors_set(self, fg, bg, *_):
        if fg >= 0:
            self.fg = rgb(fg)
        if bg >= 0:
            self.bg = rgb(bg)

    def ev_hl_attr_define(self, hl_id, attr, *_):
        self.hl[hl_id] = attr

    def ev_grid_resize(self, _grid, cols, rows):
        self.cols, self.rows = cols, rows
        self.grid = [[(" ", 0)] * cols for _ in range(rows)]

    def ev_grid_clear(self, _grid):
        self.grid = [[(" ", 0)] * self.cols for _ in range(self.rows)]

    def ev_grid_line(self, _grid, row, col, cells, *_):
        hl = 0
        for cell in cells:
            text = cell[0]
            if len(cell) > 1:
                hl = cell[1]
            for _ in range(cell[2] if len(cell) > 2 else 1):
                if col < self.cols:
                    self.grid[row][col] = (text, hl)
                col += 1

    def ev_grid_scroll(self, _grid, top, bot, left, right, rows, _cols):
        order = range(top, bot - rows) if rows > 0 else range(bot - 1, top - rows - 1, -1)
        for r in order:
            self.grid[r][left:right] = self.grid[r + rows][left:right]

    def ev_grid_cursor_goto(self, _grid, row, col):
        self.cursor = (row, col)

    def ev_mode_change(self, mode, _idx):
        self.mode = mode

    # -- drawing --------------------------------------------------------
    def colors(self, hl_id):
        a = self.hl.get(hl_id, {})
        fg = rgb(a["foreground"]) if "foreground" in a else self.fg
        bg = rgb(a["background"]) if "background" in a else self.bg
        if a.get("reverse"):
            fg, bg = bg, fg
        return fg, bg, bool(a.get("bold"))

    def render(self, chips=(), text=""):
        w = self.cols * self.cw + 2 * PAD
        h = self.rows * self.ch + 2 * PAD + CAPTION_H
        img = Image.new("RGB", (w, h), self.bg)
        d = ImageDraw.Draw(img)
        for r, line in enumerate(self.grid):
            y = PAD + r * self.ch
            for c, (ch, hl) in enumerate(line):
                fg, bg, bold = self.colors(hl)
                x = PAD + c * self.cw
                is_cursor = (r, c) == self.cursor
                if is_cursor and not self.mode.startswith(("insert", "cmdline")):
                    fg, bg = self.bg, (238, 240, 245)
                if bg != self.bg:
                    d.rectangle([x, y, x + self.cw - 1, y + self.ch - 1], fill=bg)
                if ch.strip():
                    d.text((x, y + 1), ch, font=self.bold if bold else self.font, fill=fg)
                if is_cursor and self.mode.startswith(("insert", "cmdline")):
                    d.rectangle([x, y, x + 1, y + self.ch - 1], fill=(238, 240, 245))
        # caption strip: the keys just pressed (chips) and what they do
        top = h - CAPTION_H
        d.rectangle([0, top, w, h], fill=CAPTION_BG)
        x = PAD
        cy = top + CAPTION_H // 2
        for chip in chips:
            tw = self.small_bold.getlength(chip)
            cwid = max(30, int(tw) + 18)
            d.rounded_rectangle([x, cy - 15, x + cwid, cy + 15], radius=6, fill=CHIP_BG)
            d.text((x + cwid / 2, cy), chip, font=self.small_bold, fill=CHIP_FG, anchor="mm")
            x += cwid + 6
        if chips:
            x += 8
        d.text((x, cy), text, font=self.small, fill=CAPTION_FG, anchor="lm")
        return img


class Demo:
    def __init__(self, file, cols, rows):
        nvim_bin = os.environ.get("NVIM", "nvim")
        argv = [nvim_bin, "--embed", "-n", "-i", "NONE", "-u", os.path.join(HERE, "init.lua"), os.path.join(HERE, file)]
        self.nvim = pynvim.attach("child", argv=argv)
        self.screen = Screen(cols, rows)
        self.nvim.ui_attach(cols, rows, rgb=True, ext_linegrid=True)
        self.frames = []
        self.settle(0.6)

    def settle(self, seconds=0.25):
        """Let Neovim finish (incl. the plugin's debounce) and apply its redraws."""
        end = time.time() + seconds
        while True:
            self.nvim.eval("1")
            pending = self.nvim._session._pending_messages
            while pending:
                msg = pending.popleft()
                if msg[0] == "notification" and msg[1] == "redraw":
                    self.screen.apply(msg[2])
            if time.time() >= end:
                break
            time.sleep(0.02)

    def shot(self, ms, chips=(), text=""):
        self.frames.append((self.screen.render(chips, text), ms))

    def step(self, keys, ms, chips=(), text=""):
        """Send keys, wait for the screen, record one frame shown for `ms`."""
        self.nvim.input(keys)
        self.settle()
        self.shot(ms, chips, text)

    def save(self, name):
        try:
            self.nvim.command("qa!")
        except (EOFError, OSError):
            pass  # the connection closes as Neovim exits
        os.makedirs(OUT, exist_ok=True)
        # one shared palette for every frame: stable colours, small file
        w, h = self.frames[0][0].size
        sample = Image.new("RGB", (w, h * len(self.frames)))
        for i, (img, _) in enumerate(self.frames):
            sample.paste(img, (0, i * h))
        palette = sample.quantize(colors=96, method=Image.Quantize.MEDIANCUT)
        frames = [img.quantize(palette=palette, dither=Image.Dither.NONE) for img, _ in self.frames]
        path = os.path.join(OUT, name)
        frames[0].save(
            path, save_all=True, append_images=frames[1:], duration=[ms for _, ms in self.frames],
            loop=0, optimize=True, disposal=1,
        )
        print("%s  %d frames, %.1f s, %d KB" % (
            os.path.relpath(path, ROOT), len(frames), sum(ms for _, ms in self.frames) / 1000, os.path.getsize(path) // 1024))


def demo_groups():
    """Several variables at once, each in its own colour."""
    d = Demo("invoice.lua", 62, 14)
    d.shot(1600, text="Highlight several variables at once, each in its own colour")
    d.step("2G^w", 700, text="cursor on subtotal")
    d.step("<Space>h1", 1700, ["Space", "h", "1"], "subtotal -> colour 1")
    d.step("10G^w", 700, text="cursor on tax")
    d.step("<Space>h2", 1900, ["Space", "h", "2"], "tax -> colour 2  (whole words: tax_rate stays)")
    d.step("3G^3w", 700, text="cursor on item")
    d.step("<Space>h3", 1900, ["Space", "h", "3"], "item -> colour 3  (items stays)")
    d.step("7G^w", 700, text="cursor on discount")
    d.step("<Space>h5", 2600, ["Space", "h", "5"], "discount -> colour 5  (any of 0-9)")
    d.step("10G^w", 700, text="back on tax")
    d.step("<Space>h2", 1700, ["Space", "h", "2"], "same key again: tax is switched off")
    d.step("<Space>hO", 1800, ["Space", "h", "O"], "clear all highlights")
    d.save("demo-groups.gif")


def demo_merge():
    """Find a one-letter change in a merge conflict."""
    d = Demo("Access.java", 66, 20)
    d.shot(2200, text="Merge conflict: three re-indented copies. What did theirs change?")
    d.step("<Space>hh", 1300, ["Space", "h", "h"], "live auto-highlight on")
    d.step("3G^", 600, text="go to the first line of ours")
    d.step("V", 2000, ["V"], "select the line: equal lines light up, indentation ignored")
    d.step("j", 1500, ["j"], "two lines: base and theirs still match")
    d.step("j", 3000, ["j"], "three lines: theirs drops out, so this line differs")
    d.step("<Esc>^", 700, ["Esc", "^"], "now look inside that line")
    d.step("vf(", 1700, ["v", "f", "("], "select up to the bracket: all three still match")
    for ch in "resou":
        d.step("l", 330, ["l"], "extend character by character")
    d.step("l", 1100, ["l"], "resour: all three still match")
    d.step("l", 4000, ["l"], "resourc: theirs drops out. Found it: theirs has resourse")
    d.save("demo-merge.gif")


DEMOS = {"groups": demo_groups, "merge": demo_merge}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(DEMOS):
        DEMOS[name]()
