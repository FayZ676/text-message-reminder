"""Renders the App Store product page header and search results assets.

    python3 -I AppStore/make_creative_assets.py

Reads the app icon and the screenshots in AppStore/Screenshots, writes
Header.png (3840x1646, 21:9) and SearchResults.png (3840x2560, 3:2) to
AppStore/Creative. Everything that has to be read sits inside the centered
safe areas from Apple's templates; the edges are decoration the App Store
may crop.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
ICON = ROOT.parent / "TextMessageReminder/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
SCREENSHOTS = ROOT / "Screenshots"
OUTPUT = ROOT / "Creative"

K = 2  # draw at twice the size, then downsample, so curves are antialiased
TOP, BOTTOM = (64, 200, 110), (20, 150, 210)  # the icon's gradient
INK = (28, 28, 30)
FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size * K)
    f.set_variation_by_name(weight)
    return f


def canvas(width, height):
    """The icon's green-to-blue, run diagonally, with a soft glow behind the content."""
    w, h = width * K, height * K
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x * 0.35 + y * 0.65) / 63
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
    img = small.resize((w, h), Image.BICUBIC)

    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse([w * 0.2, h * 0.1, w * 0.8, h * 0.9], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(w // 12))
    img.paste((255, 255, 255), (0, 0), glow)
    return img


def shadow(img, box, radius, blur=40, offset=24, opacity=80):
    x0, y0, x1, y1 = [v * K for v in box]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [x0, y0 + offset * K, x1, y1 + offset * K], radius=radius * K, fill=opacity
    )
    img.paste((0, 40, 70), (0, 0), mask.filter(ImageFilter.GaussianBlur(blur * K)))


def rounded(src, size, radius):
    """`src` resized to `size` with its corners rounded off."""
    w, h = size[0] * K, size[1] * K
    src = src.convert("RGB").resize((w, h), Image.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=radius * K, fill=255)
    return src, mask


def paste_icon(img, x, y, size):
    shadow(img, (x, y, x + size, y + size), size * 0.225, blur=30, offset=16, opacity=90)
    icon, mask = rounded(Image.open(ICON), (size, size), size * 0.225)
    img.paste(icon, (x * K, y * K), mask)


def phone(img, screenshot, x, y, height):
    """A plain dark-bezelled iPhone at (x, y) showing `screenshot`."""
    bezel = round(height * 0.018)
    screen_h = height - 2 * bezel
    screen_w = round(screen_h * 1320 / 2868)
    width = screen_w + 2 * bezel
    radius = width * 0.16

    shadow(img, (x, y, x + width, y + height), radius, blur=60, offset=40, opacity=110)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(
        [x * K, y * K, (x + width) * K, (y + height) * K], radius=radius * K, fill=(22, 22, 24)
    )
    screen, mask = rounded(Image.open(screenshot), (screen_w, screen_h), radius - bezel)
    img.paste(screen, ((x + bezel) * K, (y + bezel) * K), mask)
    return width


def bubble(img, x, y, text, size=56):
    """A white message bubble, tail at the bottom left, that ends up roughly at (x, y)."""
    d = ImageDraw.Draw(img)
    f = font(size, "Medium")
    left, top, right, bottom = d.textbbox((0, 0), text, font=f)
    pad_x, pad_y = 44, 30
    w = (right - left) / K + 2 * pad_x
    h = size * 1.2 + 2 * pad_y
    box = (x, y, x + w, y + h)
    shadow(img, box, h / 2, blur=24, offset=12, opacity=60)
    d.rounded_rectangle([v * K for v in box], radius=h / 2 * K, fill=(255, 255, 255))
    d.polygon(
        [((x + 14) * K, (y + h - 40) * K), ((x - 6) * K, (y + h + 6) * K), ((x + 60) * K, (y + h - 14) * K)],
        fill=(255, 255, 255),
    )
    d.text(((x + pad_x) * K - left, (y + (h - size * 1.2) / 2) * K - top + size * 0.1 * K), text, font=f, fill=INK)


def text_block(img, x, y, lines, size, weight, fill, leading=1.12):
    d = ImageDraw.Draw(img)
    f = font(size, weight)
    for i, line in enumerate(lines):
        top = d.textbbox((0, 0), line, font=f)[1]
        d.text((x * K, (y + i * size * leading) * K - top), line, font=f, fill=fill)
    return y + len(lines) * size * leading


def text_width(text, size, weight):
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    l, _, r, _ = d.textbbox((0, 0), text, font=font(size, weight))
    return (r - l) / K


def finish(img, width, height, name):
    OUTPUT.mkdir(exist_ok=True)
    out = img.resize((width, height), Image.LANCZOS).convert("RGB")
    out.save(OUTPUT / name, "PNG")
    print(OUTPUT / name, out.size)


def header():
    W, H = 3840, 1646
    img = canvas(W, H)

    # Decoration outside the safe area (1097, 493)-(2743, 1154).
    bubble(img, 150, 230, "Hi Mom! Free for a call?")
    bubble(img, 330, 760, "Courts tonight at 7?")
    bubble(img, 90, 1250, "Happy birthday Sarah!")
    bubble(img, 2930, 300, "How's the new job going?")
    bubble(img, 3080, 820, "Rent's due today")
    bubble(img, 2860, 1270, "Good morning!")

    icon = 300
    headline = ["Never forget", "to text."]
    size = 150
    block_w = icon + 70 + max(text_width(line, size, "Bold") for line in headline)
    x = round((W - block_w) / 2)
    paste_icon(img, x, round(H / 2 - icon / 2), icon)
    block_h = size * 1.12 * len(headline)
    text_block(img, x + icon + 70, H / 2 - block_h / 2, headline, size, "Bold", (255, 255, 255))

    finish(img, W, H, "Header.png")


def search_results():
    W, H = 3840, 2560
    img = canvas(W, H)

    # The front phone fits the width of the safe area (836, 765)-(3004, 1795);
    # the one behind it is decoration the App Store may crop.
    back_h, front_h = 1640, 1800
    phone(img, SCREENSHOTS / "2-birthdays.png", 2740, 440, back_h)
    phone(img, SCREENSHOTS / "1-messages.png", 2170, 380, front_h)

    x = 900
    headline = ["Schedule the text.", "Just hit Send."]
    sub = ["Pick who, what, and how often.", "We'll remind you and open", "Messages with it ready to go."]
    head_size, sub_size = 128, 68
    total = head_size * 1.12 * 2 + 60 + sub_size * 1.3 * len(sub)
    y = text_block(img, x, H / 2 - total / 2, headline, head_size, "Bold", (255, 255, 255))
    text_block(img, x, y + 60, sub, sub_size, "Medium", (240, 250, 255), leading=1.3)

    finish(img, W, H, "SearchResults.png")


if __name__ == "__main__":
    header()
    search_results()
