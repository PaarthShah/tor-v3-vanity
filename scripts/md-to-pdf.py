#!/usr/bin/env python3
"""Convert docs/junior-rust-manual.md to PDF using markdown + WeasyPrint."""
import sys
from pathlib import Path

import markdown
from weasyprint import HTML, CSS

def main():
    repo_root = Path(__file__).resolve().parent.parent
    md_path = repo_root / "docs" / "junior-rust-manual.md"
    out_path = repo_root / "docs" / "junior-rust-manual.pdf"

    text = md_path.read_text(encoding="utf-8")
    md = markdown.Markdown(extensions=["tables", "fenced_code", "nl2br"])
    body_html = md.convert(text)

    html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Junior Rust Coder Manual</title>
  <style>
    body {{ font-family: system-ui, sans-serif; line-height: 1.5; max-width: 70em; margin: 1em auto; padding: 0 1em; color: #222; }}
    h1 {{ font-size: 1.6em; border-bottom: 1px solid #ccc; padding-bottom: 0.2em; }}
    h2 {{ font-size: 1.3em; margin-top: 1.2em; }}
    h3 {{ font-size: 1.1em; margin-top: 1em; }}
    code {{ background: #f5f5f5; padding: 0.15em 0.35em; border-radius: 3px; font-size: 0.9em; }}
    pre {{ background: #f5f5f5; padding: 0.8em; overflow-x: auto; border-radius: 4px; font-size: 0.85em; }}
    pre code {{ padding: 0; background: none; }}
    table {{ border-collapse: collapse; width: 100%; margin: 0.8em 0; }}
    th, td {{ border: 1px solid #ccc; padding: 0.4em 0.6em; text-align: left; }}
    th {{ background: #eee; }}
    hr {{ border: none; border-top: 1px solid #ccc; margin: 1.5em 0; }}
    @media print {{ body {{ margin: 0; padding: 0.5em; }} }}
  </style>
</head>
<body>
{body_html}
</body>
</html>
"""

    HTML(string=html_doc, base_url=str(repo_root)).write_pdf(
        out_path,
        stylesheets=[CSS(string="@page { size: A4; margin: 2cm; }")],
    )
    print(out_path, file=sys.stderr)
    return 0

if __name__ == "__main__":
    sys.exit(main())
