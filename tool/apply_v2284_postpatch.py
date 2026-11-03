from pathlib import Path

root = Path(__file__).resolve().parents[1]

# Linovel generic chapter parsing must select the whole content container so all
# paragraphs and inline illustrations are walked by the existing DOM flattener.
path = root / "lib/book_sources.dart"
text = path.read_text(encoding="utf-8")
old = "      chapterContentSelector: '.article-text > p',"
new = "      chapterContentSelector: '.article-text',"
if text.count(old) != 1:
    raise RuntimeError(f"expected one Linovel chapter selector, found {text.count(old)}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")

# The canonical Wenku8 base is now .net, but pages/caches can still contain
# absolute .cc links. Parsing is a trust boundary too, so explicitly allow only
# these four first-party hosts rather than weakening host validation.
parser = root / "lib/wenku8_html_parser.dart"
text = parser.read_text(encoding="utf-8")
old_image_hosts = "    const officialHosts = {'www.wenku8.cc', 'wenku8.cc'};"
new_image_hosts = "    const officialHosts = {'www.wenku8.net', 'wenku8.net', 'www.wenku8.cc', 'wenku8.cc'};"
if text.count(old_image_hosts) != 1:
    raise RuntimeError("Wenku8 image host set not found")
text = text.replace(old_image_hosts, new_image_hosts, 1)
old_page_hosts = "const {'www.wenku8.cc', 'wenku8.cc'}"
new_page_hosts = "const {'www.wenku8.net', 'wenku8.net', 'www.wenku8.cc', 'wenku8.cc'}"
if text.count(old_page_hosts) != 2:
    raise RuntimeError(f"expected two Wenku8 page host checks, found {text.count(old_page_hosts)}")
text = text.replace(old_page_hosts, new_page_hosts)
parser.write_text(text, encoding="utf-8")

print("v2284 postpatch applied")
