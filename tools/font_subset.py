#!/usr/bin/env python3
"""게임에서 쓰는 글자만 남긴 한글 서브셋 글꼴을 만든다. 웹에는 OS 글꼴이 없다.

만드는 글꼴 (FONTS)
- 본문 대신 그리기: Noto Sans KR → assets/fonts/noto_sans_kr_regular_subset.ttf (게임 문구 전부, 지도 손글씨에 없는 글자를 그린다)
- 지도 할아버지 글씨: Nanum Pen Script → assets/fonts/grandpa_hand_subset.ttf (지도 문구만)
- 지도 하윤 글씨: Gamja Flower → assets/fonts/hayun_hand_subset.ttf (지도 문구만)
- 제목: Gowun Batang Bold → assets/fonts/title_subset.ttf (게임 문구의 한글·영문 — 제목·장소 이름 카드)
- 대사·메뉴·안내(기본 글꼴): Gowun Dodum → assets/fonts/ui_subset.ttf (게임 문구 전부, #100)

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
손글씨 두 개는 지도에만 쓰므로 scripts/game/map_data.gd 문자열과 위 기획서 표, MAP_EXTRA만 모은다.

게임 문구를 고치고 --check가 실패하면 이 도구를 다시 돌려 글꼴과 .import를 같이 커밋한다.
원본 글꼴은 google/fonts의 고정 커밋에서 받아 해시를 확인한다. 바꾸면 CREDITS.md도 고친다.
고친 글꼴에는 원본의 예약 글꼴 이름(OFL Reserved Font Name)을 쓰지 않는다(name의 family를 바꾼다).
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path.home() / ".cache/the-way-back"

SOURCE_COMMIT = "5bd87dfc525c8a0d1d8529d3684716e00c3fc59a"
GOOGLE_FONTS = f"https://raw.githubusercontent.com/google/fonts/{SOURCE_COMMIT}/ofl/"

# key: 무엇에 쓰나 / out: 만들 파일 / url, sha256: 원본 / weight: 가변 글꼴이면 고정할 굵기
# family: 고친 글꼴의 이름(원본 예약 이름을 피한다) / chars: "game" 게임 문구 전부, "map" 지도 문구만,
# "title" 게임 문구 중 한글 음절·기본 영문만
FONTS = [
    {
        "key": "body",
        "out": ROOT / "assets/fonts/noto_sans_kr_regular_subset.ttf",
        "url": GOOGLE_FONTS + "notosanskr/NotoSansKR%5Bwght%5D.ttf",
        "sha256": "194018e6b2b293a7964f037b25c0249ce1418bc9ab3c971060a03aa57861e252",
        "weight": 400,
        "family": "Noto Sans KR",
        "chars": "game",
    },
    {
        "key": "title",
        "out": ROOT / "assets/fonts/title_subset.ttf",
        "url": GOOGLE_FONTS + "gowunbatang/GowunBatang-Bold.ttf",
        "sha256": "dbfcaa646e5831e7478524924f02906f550285a5050699b4e38c9950b3ec4b94",
        "weight": None,
        "family": "Way Back Title",
        "chars": "title",
    },
    {
        "key": "ui",
        "out": ROOT / "assets/fonts/ui_subset.ttf",
        "url": GOOGLE_FONTS + "gowundodum/GowunDodum-Regular.ttf",
        "sha256": "a6e457933227483a11758fd0947bc74422a106d46f0bf057fdaa5af94a30067d",
        "weight": None,
        "family": "Way Back UI",
        "chars": "game",
    },
    {
        "key": "grandpa",
        "out": ROOT / "assets/fonts/grandpa_hand_subset.ttf",
        "url": GOOGLE_FONTS + "nanumpenscript/NanumPenScript-Regular.ttf",
        "sha256": "6f0d1ab29c7894010dc88831fb7a0a51edb79136e450344183de5b1a8b52bd43",
        "weight": None,
        "family": "Way Back Grandpa Hand",
        "chars": "map",
    },
    {
        "key": "hayun",
        "out": ROOT / "assets/fonts/hayun_hand_subset.ttf",
        "url": GOOGLE_FONTS + "gamjaflower/GamjaFlower-Regular.ttf",
        "sha256": "ece32819ed58536355a49a095b0cdfdd3b8ef9081c5ed9ca1cef8f5d999ae1ac",
        "weight": None,
        "family": "Way Back Hayun Hand",
        "chars": "map",
    },
]
MAP_DATA = ROOT / "scripts/game/map_data.gd"

# 어디서도 안 모이더라도 늘 넣는 글자.
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
EXTRA = ASCII + "…·‘’“”—–「」『』～￦"
# 손글씨 원본에는 특수 문장부호(—, 「」 등)가 없다. 지도에는 영문·숫자·기본 문장부호만 늘 넣는다.
MAP_EXTRA = ASCII

STRING_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
GD_COMMENT_RE = re.compile(r'^\s*#.*$', re.MULTILINE)
# "## 3. 버려진 간이역 (8:40~14:20)" → "버려진 간이역"
STORY_PLACE_RE = re.compile(r'^## \d+\. ([^(\n]+)', re.MULTILINE)


def _title_char(ch: str) -> bool:
    return "\uac00" <= ch <= "\ud7a3" or (ch in ASCII and ch != "`")


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


def collect(scope: str = "game") -> dict[str, list[str]]:
    """글자 → 처음 나온 파일들. scope "map"이면 지도 문구만.
    scope "title"이면 게임 문구 중 한글 음절과 기본 영문·숫자·문장부호만(제목 글꼴에는
    화살표·「」 같은 기호가 없다. 제목·장소 이름 카드에는 그런 기호를 쓰지 않는다)."""
    if scope == "title":
        return {ch: origin for ch, origin in collect("game").items() if _title_char(ch)}
    where: dict[str, list[str]] = {}

    def add(chars: str, origin: str) -> None:
        for ch in chars:
            if ch in "\n\r\t":
                continue
            where.setdefault(ch, [])
            if origin not in where[ch]:
                where[ch].append(origin)

    if scope == "map":
        add(_strings(GD_COMMENT_RE.sub("", MAP_DATA.read_text(encoding="utf-8"))), str(MAP_DATA.relative_to(ROOT)))
        add(_map_table((ROOT / "docs/design.md").read_text(encoding="utf-8")), "docs/design.md")
        add(MAP_EXTRA, "MAP_EXTRA")
        return where

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


def _source_font(spec: dict) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{spec['key']}-{SOURCE_COMMIT[:8]}-{Path(spec['url']).name.replace('%5B', '[').replace('%5D', ']')}"
    if not path.exists():
        print(f"원본 글꼴 받는 중: {spec['url']}")
        urllib.request.urlretrieve(spec["url"], path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != spec["sha256"]:
        path.unlink()
        sys.exit(f"원본 글꼴 해시가 다르다({spec['key']}): {digest}")
    return path


def build(spec: dict, chars: str) -> None:
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    font = TTFont(_source_font(spec))
    weight = spec["weight"]
    if weight is not None:
        font = instancer.instantiateVariableFont(font, {"wght": weight})
    # 같은 글자면 같은 파일이 나오게 저장 시각을 원본 그대로 둔다.
    font.recalcTimestamp = False

    # 굵기 하나만 남겼으니 이름도 Regular로 맞춘다. 저작권·라이선스 줄(0, 13, 14)은 그대로 둔다.
    # 손글씨는 원본 예약 이름(Nanum 등)을 피해 family를 바꾼다.
    family = spec["family"]
    name = font["name"]
    if spec["key"] != "body":
        # 다른 언어로 남은 원본 이름 줄(한국어 이름 등)까지 지우고 새로 쓴다.
        for rec_id in (1, 2, 3, 4, 6):
            name.removeNames(nameID=rec_id)
    for rec_id, value in {
        1: family,
        2: "Regular",
        3: f"{family.replace(' ', '')}-Regular-subset",
        4: f"{family} Regular",
        6: f"{family.replace(' ', '')}-Regular",
    }.items():
        name.setName(value, rec_id, 3, 1, 0x409)
        name.setName(value, rec_id, 1, 0, 0)
    for rec_id in (16, 17, 21, 22, 25):
        name.removeNames(nameID=rec_id)
    if weight is not None:
        font["OS/2"].usWeightClass = weight

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=chars)
    subsetter.subset(font)

    out: Path = spec["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    font.save(out)
    print(f"{out.relative_to(ROOT)}: 글자 {len(chars)}개, {out.stat().st_size // 1024} KB")


def check(spec: dict, where: dict[str, list[str]]) -> int:
    from fontTools.ttLib import TTFont

    out: Path = spec["out"]
    rel = out.relative_to(ROOT)
    if not out.exists():
        print(f"FAIL 글꼴이 없다: {rel}")
        return 1
    cmap = TTFont(out).getBestCmap()
    missing = sorted(ch for ch in where if ord(ch) not in cmap)
    if not missing:
        print(f"ok    {rel}: 쓰는 글자 {len(where)}개가 모두 글꼴에 있다")
        return 0
    for ch in missing:
        print(f"FAIL  {rel}: '{ch}' (U+{ord(ch):04X}) 글꼴에 없음 — {', '.join(where[ch][:3])}")
    print("python3 tools/font_subset.py 로 글꼴을 다시 만들어 커밋한다.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="글꼴에 빠진 글자가 있는지만 본다")
    parser.add_argument("--list", action="store_true", help="모은 글자를 출력한다")
    parser.add_argument("--only", choices=[f["key"] for f in FONTS], help="이 글꼴만")
    args = parser.parse_args()

    failed = 0
    for spec in FONTS:
        if args.only and spec["key"] != args.only:
            continue
        where = collect(spec["chars"])
        chars = "".join(sorted(where))
        if args.list:
            print(f"{spec['key']}: {chars}")
            continue
        if not args.check:
            build(spec, chars)
        failed += check(spec, where)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
