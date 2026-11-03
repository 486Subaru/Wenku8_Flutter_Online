from pathlib import Path

path = Path(__file__).resolve().parents[1] / "lib/book_sources.dart"
text = path.read_text(encoding="utf-8")
old = "      chapterContentSelector: '.article-text > p',"
new = "      chapterContentSelector: '.article-text',"
if text.count(old) != 1:
    raise RuntimeError(f"expected one Linovel chapter selector, found {text.count(old)}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
print("v2284 Linovel chapter hotfix applied")
