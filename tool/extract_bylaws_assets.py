from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parents[1] / "assets" / "bylaws"
out.mkdir(parents=True, exist_ok=True)

asp_src = (root / "src" / "app" / "data" / "asp-bylaws.ts").read_text(encoding="utf-8")
marker = "export const ASP_BYLAWS_TEXT ="
start = asp_src.find(marker)
first = asp_src.find("`", start)
last = asp_src.rfind("`")
asp_text = asp_src[first + 1 : last].replace("\r\n", "\n").strip() + "\n"
(out / "asp.txt").write_text(asp_text, encoding="utf-8")

obra_src = (root / "src" / "app" / "data" / "org-bylaws.ts").read_text(encoding="utf-8")
block_start = obra_src.find("const OBRA_BYLAWS")
block_end = obra_src.find("const BYLAWS_BY_ORG")
block = obra_src[block_start:block_end]


def read_str(src: str, i: int) -> tuple[str, int]:
    quote = src[i]
    i += 1
    chars: list[str] = []
    while i < len(src):
        ch = src[i]
        if ch == "\\" and i + 1 < len(src):
            nxt = src[i + 1]
            chars.append("\n" if nxt == "n" else nxt)
            i += 2
            continue
        if ch == quote:
            return "".join(chars), i + 1
        chars.append(ch)
        i += 1
    return "".join(chars), i


parts = [
    "College of Computer Studies",
    "OBRA Creative Media Productions",
    "",
    "Constitution and By-Laws of OBRA: CCS Creative Media Production Organization",
    "",
]
i = 0
while i < len(block):
    if block.startswith("title: ", i) or block.startswith("heading: ", i) or block.startswith("paragraphs: ", i):
        key_end = block.find(":", i)
        j = block.find("'", key_end)
        if j == -1:
            j = block.find('"', key_end)
        if j == -1:
            i += 1
            continue
        if block.startswith("paragraphs: ", i):
            k = block.find("[", i)
            i = k + 1 if k != -1 else i + 1
            while i < len(block) and block[i] != "]":
                if block[i] in "'\"":
                    text, i = read_str(block, i)
                    parts.append(text)
                else:
                    i += 1
            parts.append("")
            continue
        text, i = read_str(block, j)
        parts.append(text)
        if block.startswith("title: ", i - len(text) - 8):
            parts.append("")
        continue
    i += 1

obra_text = "\n".join(parts).replace("\n\n\n", "\n\n").strip() + "\n"
(out / "obra.txt").write_text(obra_text, encoding="utf-8")
print("asp", len(asp_text), "obra", len(obra_text))
