#!/usr/bin/env python3
"""게임에서 쓰는 글자만 남긴 한글 서브셋 글꼴을 만든다. 웹에는 OS 글꼴이 없다.

    python3 tools/font_subset.py           # 글꼴을 다시 만든다
    python3 tools/font_subset.py --check   # 쓰는 글자가 글꼴에 다 있는지만 본다(CI)
    python3 tools/font_subset.py --list    # 모은 글자를 보여 준다

필요한 것: pip install fonttools

글자를 모으는 곳
- scenes/**/*.tscn, scripts/**/*.gd, data/** 의 따옴표 안 문자열 (주석은 뺀다)
- docs/story.md 의 따옴표 안 문자열(대사·글)과 장소 제목
- docs/design.md "지도의 다섯 동그라미" 표의 장소 이름과 메모
  (아직 게임 파일에 없는 문구까지 미리 넣는다)
- 영문·숫자·문장부호 (EXTRA)

게임 문구를 고치고 --check가 실패하면 이 도구를 다시 돌려 글꼴과 .import를 같이 커밋한다.
원본 글꼴은 google/fonts의 고정 커밋에서 받아 해시를 확인한다. 바꾸면 CREDITS.md도 고친다.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/fonts/noto_sans_kr_regular_subset.ttf"
CACHE = Path.home() / ".cache/the-way-back"

SOURCE_COMMIT = "5bd87dfc525c8a0d1d8529d3684716e00c3fc59a"
SOURCE_URL = (
    "https://raw.githubusercontent.com/google/fonts/"
    f"{SOURCE_COMMIT}/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf"
)
SOURCE_SHA256 = "194018e6b2b293a7964f037b25c0249ce1418bc9ab3c971060a03aa57861e252"
WEIGHT = 400
FAMILY = "Noto Sans KR"

# 어디서도 안 모이더라도 늘 넣는 글자.
EXTRA = "".join(chr(c) for c in range(0x20, 0x7F)) + "…·‘’“”—–「」『』～￦"

STRING_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
GD_COMMENT_RE = re.compile(r'^\s*#.*$', re.MULTILINE)
# "## 3. 버려진 간이역 (8:40~14:20)" → "버려진 간이역"
STORY_PLACE_RE = re.compile(r'^## \d+\. ([^(\n]+)', re.MULTILINE)


def _strings(text: str) -> str:
    return "".join(STRING_RE.findall(text))


def _map_table(design: str) -> str:
    """기획서 "지도의 다섯 동그라미" 표의 장소·메모 칸."""
    section = design.split("## 지도의 다섯 동그라미", 1)[-1].split("\n## ", 1)[0]
    cells = []
    for line in section.splitlines():
        parts = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(parts) == 3 and parts[0].isdigit():
            cells += [parts[1], "".join(STRING_RE.findall(parts[2]))]
    return "".join(cells)


def _game_files() -> list[Path]:
    files: list[Path] = []
    for pattern in ("scenes/**/*.tscn", "scripts/**/*.gd", "data/**/*"):
        files += [p for p in ROOT.glob(pattern) if p.is_file()]
    return sorted(files)


def collect() -> dict[str, list[str]]:
    """글자 → 처음 나온 파일들."""
    where: dict[str, list[str]] = {}

    def add(chars: str, origin: str) -> None:
        for ch in chars:
            if ch in "\n\r\t":
                continue
            where.setdefault(ch, [])
            if origin not in where[ch]:
                where[ch].append(origin)

    for path in _game_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        if path.suffix == ".gd":
            text = GD_COMMENT_RE.sub("", text)
        rel = str(path.relative_to(ROOT))
        add(_strings(text) if path.suffix in (".gd", ".tscn", ".tres") else text, rel)

    story = (ROOT / "docs/story.md").read_text(encoding="utf-8")
    add(_strings(story) + "".join(STORY_PLACE_RE.findall(story)), "docs/story.md")
    add(_map_table((ROOT / "docs/design.md").read_text(encoding="utf-8")), "docs/design.md")
    add(EXTRA, "EXTRA")
    return where


def _source_font() -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"NotoSansKR-VF-{SOURCE_COMMIT[:8]}.ttf"
    if not path.exists():
        print(f"원본 글꼴 받는 중: {SOURCE_URL}")
        urllib.request.urlretrieve(SOURCE_URL, path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        path.unlink()
        sys.exit(f"원본 글꼴 해시가 다르다: {digest}")
    return path


def build(chars: str) -> None:
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    font = TTFont(_source_font())
    font = instancer.instantiateVariableFont(font, {"wght": WEIGHT})
    # 같은 글자면 같은 파일이 나오게 저장 시각을 원본 그대로 둔다.
    font.recalcTimestamp = False

    # 굵기 하나만 남겼으니 이름도 Regular로 맞춘다. 저작권·라이선스 줄(0, 13, 14)은 그대로 둔다.
    name = font["name"]
    for rec_id, value in {
        1: FAMILY,
        2: "Regular",
        3: f"{FAMILY.replace(' ', '')}-Regular-subset",
        4: f"{FAMILY} Regular",
        6: f"{FAMILY.replace(' ', '')}-Regular",
    }.items():
        name.setName(value, rec_id, 3, 1, 0x409)
        name.setName(value, rec_id, 1, 0, 0)
    for rec_id in (16, 17, 21, 22, 25):
        name.removeNames(nameID=rec_id)
    font["OS/2"].usWeightClass = WEIGHT

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=chars)
    subsetter.subset(font)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    print(f"{OUT.relative_to(ROOT)}: 글자 {len(chars)}개, {OUT.stat().st_size // 1024} KB")


def check(where: dict[str, list[str]]) -> int:
    from fontTools.ttLib import TTFont

    if not OUT.exists():
        print(f"FAIL 글꼴이 없다: {OUT.relative_to(ROOT)}")
        return 1
    cmap = TTFont(OUT).getBestCmap()
    missing = sorted(ch for ch in where if ord(ch) not in cmap)
    if not missing:
        print(f"ok    쓰는 글자 {len(where)}개가 모두 글꼴에 있다")
        return 0
    for ch in missing:
        print(f"FAIL  '{ch}' (U+{ord(ch):04X}) 글꼴에 없음 — {', '.join(where[ch][:3])}")
    print("python3 tools/font_subset.py 로 글꼴을 다시 만들어 커밋한다.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="글꼴에 빠진 글자가 있는지만 본다")
    parser.add_argument("--list", action="store_true", help="모은 글자를 출력한다")
    args = parser.parse_args()

    where = collect()
    chars = "".join(sorted(where))
    if args.list:
        print(chars)
        return 0
    if args.check:
        return check(where)
    build(chars)
    return check(where)


if __name__ == "__main__":
    sys.exit(main())
