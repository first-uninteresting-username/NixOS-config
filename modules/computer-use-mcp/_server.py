"""MCP server that lets an agent see and control the X11 desktop it runs on."""

import io
import os
import subprocess
from pathlib import Path

from mcp.server.mcpserver import Image, MCPServer
from PIL import Image as PILImage

XDOTOOL = "@xdotool@"
MAIM = "@maim@"
# Screenshots are downscaled to this width; tool coordinates use screenshot pixels.
MAX_WIDTH = int(os.environ.get("COMPUTER_USE_MAX_WIDTH", "1280"))
BUTTONS = {"left": 1, "middle": 2, "right": 3}
SCROLL = {"up": 4, "down": 5, "left": 6, "right": 7}

mcp = MCPServer("computer")


def ensure_display():
    """Use the user's newest X server when the agent starts without DISPLAY, e.g. over SSH."""
    if os.environ.get("DISPLAY"):
        return
    sockets = [
        s for s in Path("/tmp/.X11-unix").glob("X*")
        if s.stat().st_uid == os.getuid()
    ]
    if not sockets:
        raise RuntimeError("DISPLAY is unset and no X server owned by this user was found")
    newest = max(sockets, key=lambda s: s.stat().st_mtime)
    os.environ["DISPLAY"] = ":" + newest.name[1:]


def xdotool(*args):
    ensure_display()
    result = subprocess.run(
        [XDOTOOL, *map(str, args)], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "xdotool failed")
    return result.stdout.strip()


def scale():
    width = int(xdotool("getdisplaygeometry").split()[0])
    return max(width / MAX_WIDTH, 1.0)


def to_screen(x, y):
    factor = scale()
    return round(x * factor), round(y * factor)


@mcp.tool()
def screenshot() -> Image:
    """Capture the whole screen. Use its pixel coordinates for every other tool."""
    ensure_display()
    png = subprocess.run([MAIM, "--format=png", "--hidecursor"],
                         capture_output=True, check=True).stdout
    image = PILImage.open(io.BytesIO(png)).convert("RGB")
    factor = max(image.width / MAX_WIDTH, 1.0)
    if factor > 1.0:
        size = (round(image.width / factor), round(image.height / factor))
        image = image.resize(size, PILImage.Resampling.LANCZOS)
    out = io.BytesIO()
    image.save(out, format="PNG", optimize=True)
    return Image(data=out.getvalue(), format="png")


@mcp.tool()
def click(x: int, y: int, button: str = "left", count: int = 1) -> str:
    """Move the pointer to (x, y) and click; button is left, middle or right."""
    sx, sy = to_screen(x, y)
    xdotool("mousemove", "--sync", sx, sy, "click", "--repeat", count, BUTTONS[button])
    return f"clicked {button} x{count} at ({x}, {y})"


@mcp.tool()
def move(x: int, y: int) -> str:
    """Move the pointer to (x, y) without clicking."""
    sx, sy = to_screen(x, y)
    xdotool("mousemove", "--sync", sx, sy)
    return f"moved to ({x}, {y})"


@mcp.tool()
def drag(start_x: int, start_y: int, end_x: int, end_y: int) -> str:
    """Press the left button at the start point, move to the end point and release."""
    sx, sy = to_screen(start_x, start_y)
    ex, ey = to_screen(end_x, end_y)
    xdotool("mousemove", "--sync", sx, sy, "mousedown", 1,
            "mousemove", "--sync", ex, ey, "mouseup", 1)
    return f"dragged ({start_x}, {start_y}) to ({end_x}, {end_y})"


@mcp.tool()
def scroll(x: int, y: int, direction: str = "down", amount: int = 3) -> str:
    """Scroll at (x, y); direction is up, down, left or right."""
    sx, sy = to_screen(x, y)
    xdotool("mousemove", "--sync", sx, sy, "click", "--repeat", amount, SCROLL[direction])
    return f"scrolled {direction} {amount} at ({x}, {y})"


@mcp.tool()
def type_text(text: str) -> str:
    """Type text into the focused window."""
    xdotool("type", "--clearmodifiers", "--delay", 12, "--", text)
    return f"typed {len(text)} characters"


@mcp.tool()
def key(keys: str) -> str:
    """Press keys in xdotool syntax, e.g. "Return", "ctrl+l" or "alt+Tab ctrl+c"."""
    xdotool("key", "--clearmodifiers", "--", *keys.split())
    return f"pressed {keys}"


@mcp.tool()
def cursor_position() -> str:
    """Return the pointer position in screenshot coordinates."""
    values = dict(
        line.split("=") for line in xdotool("getmouselocation", "--shell").splitlines()
    )
    factor = scale()
    return f"({round(int(values['X']) / factor)}, {round(int(values['Y']) / factor)})"


if __name__ == "__main__":
    mcp.run()
