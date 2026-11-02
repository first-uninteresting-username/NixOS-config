"""MCP server that lets an agent see and control the X11 desktop it runs on."""

import io
import math
import os
import subprocess
import time
from pathlib import Path

from mcp.server.mcpserver import Image, MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from PIL import Image as PILImage

XDOTOOL = "@xdotool@"
MAIM = "@maim@"
# Claude downscales larger images itself; matching its limits keeps coordinates exact.
MAX_EDGE = int(os.environ.get("COMPUTER_USE_MAX_EDGE", "1568"))
MAX_PIXELS = int(os.environ.get("COMPUTER_USE_MAX_PIXELS", "1150000"))
BUTTONS = {"left": 1, "middle": 2, "right": 3}
SCROLL = {"up": 4, "down": 5, "left": 6, "right": 7}

mcp = MCPServer(
    "computer",
    instructions=(
        "Controls the X11 desktop this agent runs on. Call screenshot first; every coordinate "
        "uses screenshot pixels. Use zoom to read small text and actions to run several "
        "steps in one call."
    ),
)


def ensure_display():
    """Use the user's newest X server when the agent starts without DISPLAY, e.g. over SSH."""
    if os.environ.get("DISPLAY"):
        return
    sockets = [
        s for s in Path("/tmp/.X11-unix").glob("X*")
        if s.stat().st_uid == os.getuid()
    ]
    if not sockets:
        raise ToolError("DISPLAY is unset and no X server owned by this user was found")
    newest = max(sockets, key=lambda s: s.stat().st_mtime)
    os.environ["DISPLAY"] = ":" + newest.name[1:]


def xdotool(*args):
    ensure_display()
    result = subprocess.run(
        [XDOTOOL, *map(str, args)], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise ToolError(result.stderr.strip() or "xdotool failed")
    return result.stdout.strip()


def fit_factor(width, height):
    """Return the downscale factor that fits an image within the image limits."""
    return max(width / MAX_EDGE, height / MAX_EDGE,
               math.sqrt(width * height / MAX_PIXELS), 1.0)


def scale():
    width, height = map(int, xdotool("getdisplaygeometry").split())
    return fit_factor(width, height)


def to_screen(x, y):
    factor = scale()
    return round(x * factor), round(y * factor)


def from_screen(x, y):
    factor = scale()
    return round(x / factor), round(y / factor)


def capture(region=None):
    ensure_display()
    args = [MAIM, "--format=png", "--hidecursor"]
    if region:
        args.append("--geometry={2}x{3}+{0}+{1}".format(*region))
    result = subprocess.run(args, capture_output=True, check=False)
    if result.returncode != 0:
        raise ToolError(result.stderr.decode(errors="replace").strip() or "maim failed")
    png = result.stdout
    image = PILImage.open(io.BytesIO(png)).convert("RGB")
    factor = fit_factor(image.width, image.height)
    if factor > 1.0:
        size = (round(image.width / factor), round(image.height / factor))
        image = image.resize(size, PILImage.Resampling.LANCZOS)
    out = io.BytesIO()
    image.save(out, format="PNG", optimize=True)
    return Image(data=out.getvalue(), format="png")


def pointer(x, y):
    """Return xdotool arguments that move the pointer, or none to act at its position."""
    if x is None or y is None:
        return []
    return ["mousemove", "--sync", *to_screen(x, y)]


def with_modifiers(modifiers, args):
    """Wrap xdotool arguments in keydown/keyup for modifiers such as "ctrl+shift"."""
    keys = [k for k in (modifiers or "").split("+") if k]
    down = [a for k in keys for a in ("keydown", k)]
    up = [a for k in reversed(keys) for a in ("keyup", k)]
    return down + args + up


@mcp.tool()
def screenshot() -> Image:
    """Capture the whole screen. Use its pixel coordinates for every other tool."""
    return capture()


@mcp.tool()
def zoom(x: int, y: int, width: int, height: int) -> Image:
    """Capture a screenshot-coordinate region at full screen resolution to read small text."""
    left, top = to_screen(x, y)
    right, bottom = to_screen(x + width, y + height)
    return capture((left, top, right - left, bottom - top))


@mcp.tool()
def click(x: int | None = None, y: int | None = None, button: str = "left",
          count: int = 1, modifiers: str = "") -> str:
    """Click at (x, y), or at the pointer when omitted.

    button is left, middle or right; count 2 or 3 double- or triple-clicks;
    modifiers holds keys such as "ctrl" or "ctrl+shift" during the click.
    """
    xdotool(*pointer(x, y), *with_modifiers(
        modifiers, ["click", "--repeat", count, BUTTONS[button]]))
    return f"clicked {button} x{count} at {cursor_position()}"


@mcp.tool()
def move(x: int, y: int) -> str:
    """Move the pointer to (x, y) without clicking, e.g. to hover."""
    xdotool(*pointer(x, y))
    return f"moved to ({x}, {y})"


@mcp.tool()
def drag(start_x: int, start_y: int, end_x: int, end_y: int,
         button: str = "left", modifiers: str = "") -> str:
    """Press a button at the start point, move to the end point and release."""
    b = BUTTONS[button]
    xdotool(*pointer(start_x, start_y), *with_modifiers(
        modifiers, ["mousedown", b, *pointer(end_x, end_y), "mouseup", b]))
    return f"dragged ({start_x}, {start_y}) to ({end_x}, {end_y})"


@mcp.tool()
def scroll(x: int | None = None, y: int | None = None, direction: str = "down",
           amount: int = 3, modifiers: str = "") -> str:
    """Scroll at (x, y), or at the pointer; direction is up, down, left or right."""
    xdotool(*pointer(x, y), *with_modifiers(
        modifiers, ["click", "--repeat", amount, SCROLL[direction]]))
    return f"scrolled {direction} {amount}"


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
def wait(seconds: float = 1.0) -> str:
    """Pause, e.g. while an application starts or a page loads; at most 30 seconds."""
    seconds = min(max(seconds, 0.0), 30.0)
    time.sleep(seconds)
    return f"waited {seconds} s"


@mcp.tool()
def cursor_position() -> str:
    """Return the pointer position in screenshot coordinates."""
    values = dict(
        line.split("=") for line in xdotool("getmouselocation", "--shell").splitlines()
    )
    return str(from_screen(int(values["X"]), int(values["Y"])))


@mcp.tool()
def windows() -> str:
    """List visible windows with their ID, title and screenshot-coordinate geometry."""
    try:
        ids = xdotool("search", "--onlyvisible", "--name", ".").split()
    except ToolError:
        return "no windows"
    try:
        active = xdotool("getactivewindow")
    except ToolError:
        active = None
    lines = []
    for wid in ids:
        geometry = dict(
            line.split("=")
            for line in xdotool("getwindowgeometry", "--shell", wid).splitlines()
        )
        x, y = from_screen(int(geometry["X"]), int(geometry["Y"]))
        w, h = from_screen(int(geometry["WIDTH"]), int(geometry["HEIGHT"]))
        if w < 2 or h < 2:
            continue
        name = xdotool("getwindowname", wid)
        mark = "*" if wid == active else " "
        lines.append(f"{mark} {wid} ({x}, {y}) {w}x{h} {name}")
    return "\n".join(lines) or "no windows"


@mcp.tool()
def focus_window(window_id: int) -> str:
    """Raise and focus a window by an ID from windows."""
    xdotool("windowactivate", "--sync", window_id)
    return f"focused {window_id}"


TOOLS = {
    f.__name__: f
    for f in (click, move, drag, scroll, type_text, key, wait, focus_window)
}


@mcp.tool()
def actions(steps: list[dict], screenshot_after: bool = True) -> list:
    """Run several steps in one call, then optionally return a screenshot.

    Each step names a tool and its arguments, e.g.
    [{"action": "click", "x": 40, "y": 60}, {"action": "type_text", "text": "hi"},
     {"action": "key", "keys": "Return"}, {"action": "wait", "seconds": 1}].
    Supported actions: click, move, drag, scroll, type_text, key, wait, focus_window.
    Execution stops at the first failing step.
    """
    log = []
    for number, step in enumerate(steps, 1):
        args = dict(step)
        name = args.pop("action", None)
        if name not in TOOLS:
            log.append(f"{number}. unknown action {name!r}; stopped")
            break
        try:
            log.append(f"{number}. {TOOLS[name](**args)}")
        except Exception as error:  # Report any failure to the agent.
            log.append(f"{number}. {name} failed: {error}; stopped")
            break
    result = ["\n".join(log)]
    if screenshot_after:
        result.append(capture())
    return result


if __name__ == "__main__":
    mcp.run()
