"""Render Jigu's public Markdown policies as simple GitHub Pages HTML."""
from html import escape
from pathlib import Path
import re

SOURCE = Path(__file__).resolve().parents[1] / "public_policy"
OUTPUT = SOURCE / "docs"
PAGES = {
    "CHILD_SAFETY.md": ("child-safety.html", "Child safety standards"),
    "PRIVACY_POLICY.md": ("privacy.html", "Privacy policy"),
    "TERMS_OF_USE.md": ("terms.html", "Terms of use"),
    "DELETE_ACCOUNT.md": ("delete-account.html", "Delete account"),
}


def inline(value: str) -> str:
    value = escape(value)
    value = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"`(.+?)`", r"<code>\1</code>", value)

    def link(match: re.Match[str]) -> str:
        label, target = match.groups()
        target = {
            "CHILD_SAFETY.md": "child-safety.html",
            "PRIVACY_POLICY.md": "privacy.html",
            "TERMS_OF_USE.md": "terms.html",
            "DELETE_ACCOUNT.md": "delete-account.html",
        }.get(target, target)
        if not (target.startswith(("https://", "mailto:")) or target.endswith(".html")):
            return label
        return f'<a href="{escape(target, quote=True)}">{label}</a>'

    return re.sub(r"\[(.+?)\]\((.+?)\)", link, value)


def render_markdown(source: str) -> str:
    output: list[str] = []
    paragraph: list[str] = []
    in_list = False

    def flush() -> None:
        nonlocal paragraph
        if paragraph:
            output.append("<p>" + " ".join(inline(part) for part in paragraph) + "</p>")
            paragraph = []

    for raw in source.splitlines():
        line = raw.strip()
        if not line:
            flush()
            if in_list:
                output.append("</ul>")
                in_list = False
        elif line.startswith("# "):
            flush()
            output.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            flush()
            if in_list:
                output.append("</ul>")
                in_list = False
            output.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            flush()
            if not in_list:
                output.append("<ul>")
                in_list = True
            output.append(f"<li>{inline(line[2:])}</li>")
        else:
            paragraph.append(line.rstrip(" "))
    flush()
    if in_list:
        output.append("</ul>")
    return "\n".join(output)


def frame(title: str, body: str) -> str:
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light"><title>{escape(title)} · Jigu</title>
<style>
:root{{color-scheme:light;--plum:#613348;--pink:#d86b93;--sage:#71856a;--ink:#473b42}}
*{{box-sizing:border-box}}body{{margin:0;background:#fff9fa;color:var(--ink);font:17px/1.65 system-ui,-apple-system,Segoe UI,sans-serif}}
header{{background:#f9e4ec;border-bottom:1px solid #e8c5d1;padding:16px 20px}}nav{{max-width:820px;margin:auto;display:flex;align-items:center;gap:18px;flex-wrap:wrap}}
nav a{{color:var(--plum);text-decoration:none;font-size:14px}}nav a:first-child{{font-weight:750;font-size:23px;margin-right:auto}}
main{{max-width:820px;margin:30px auto 70px;padding:30px clamp(20px,5vw,50px);background:white;border:1px solid #edd8df;border-radius:24px}}
h1,h2{{color:var(--plum);line-height:1.25}}h1{{font-size:clamp(30px,5vw,42px);margin:0 0 28px}}h2{{font-size:23px;margin:34px 0 10px}}
a{{color:#9f315d}}a:hover{{text-decoration-thickness:2px}}li{{margin:7px 0}}code{{background:#f8edf0;padding:2px 5px;border-radius:4px}}
footer{{max-width:820px;margin:0 auto 40px;padding:0 20px;color:#806674;font-size:14px}}:focus-visible{{outline:3px solid var(--pink);outline-offset:3px}}
@media(max-width:600px){{main{{margin:0;padding:22px 20px;border:0;border-radius:0}}nav{{gap:10px}}nav a:first-child{{width:100%}}}}
</style></head><body><header><nav aria-label="Main navigation"><a href="index.html">✿ jigu</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a><a href="delete-account.html">Delete account</a></nav></header>
<main>{body}</main><footer>Jigu · Sanjaya Rajbhandari · <a href="mailto:sanjaynewar007@gmail.com">Contact</a></footer></body></html>'''


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    for source_name, (target_name, title) in PAGES.items():
        (OUTPUT / target_name).write_text(
            frame(title, render_markdown((SOURCE / source_name).read_text(encoding="utf-8"))),
            encoding="utf-8",
        )
    home = "<h1>Jigu</h1><p>A private little space for two, made by Sanjaya Rajbhandari.</p><p>Read how Jigu handles your data and how to contact us.</p><ul><li><a href='privacy.html'>Privacy policy</a></li><li><a href='terms.html'>Terms of use</a></li><li><a href='delete-account.html'>Delete account and data</a></li></ul>"
    (OUTPUT / "index.html").write_text(frame("Jigu information", home), encoding="utf-8")
    (OUTPUT / ".nojekyll").write_text("", encoding="utf-8")


if __name__ == "__main__":
    main()
