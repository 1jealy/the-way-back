#!/usr/bin/env python3
"""인물 그림 PSD를 컷아웃 조각 PNG로 자른다(기획서 "컷아웃 조립 도구"의 앞 단계).

    python3 tools/psd_split.py <그림.psd>            # assets/art/char/<인물>/ 에 조각을 쓴다
    python3 tools/psd_split.py <그림.psd> --check    # 쓰지 않고 규칙만 본다
    python3 tools/psd_split.py <그림.psd> --out <폴더>

필요한 것: pip install psd-tools==1.27.0

클립 스튜디오에서 PSD로 저장해서 받는다(.clip은 읽지 않는다). 레이어 규칙:
- 맨 위 폴더 하나 = 인물 하나. 폴더 이름이 인물 이름이다(예: hayun, dog, grandpa).
- 폴더 안 레이어 하나 = 조각 하나. 레이어 이름이 부위 이름이다(예: head, arm_l_upper).
  폴더 안 폴더는 이름을 _로 잇는다: hayun/eye/open → char_hayun_eye_open.png
- 이름은 영어 소문자·숫자·_ 만. 같은 인물 안에서 부위 이름이 겹치면 안 된다.
- 머리는 눈 없이 그리고(눈 자리까지 피부를 칠한다) 눈·입·눈썹은 상태마다 따로 그린다
  (eye_open / eye_half / eye_closed …). 깜빡임·표정은 게임이 조각을 바꿔 끼워 만든다.
- 클리핑·효과·합성 모드(곱하기 등) 레이어는 부위별로 합쳐 일반 레이어로 만든다.
  자를 때 그 효과가 같이 따라오지 않는다(도구가 찾아서 알려 준다).
- 숨긴 레이어는 건너뛴다(조각에서 빠진다).

만드는 것(assets/art/char/<인물>/):
- char_<인물>_<부위>.png  조각(투명 배경, 그려진 부분만 잘라 냄)
- char_<인물>.json        캔버스 크기, 조각마다 캔버스 위 자리(x, y, w, h)와 그리는 순서(z, 0이 맨 아래)
  조립 도구는 이 자리대로 놓으면 PSD에서 본 모습 그대로 맞춰진다.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/art/char"
NAME_RE = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")


def _norm(name: str) -> str:
    return name.strip().lower().replace(" ", "_").replace("-", "_")


def _layer_problems(layer) -> list[str]:
    """자를 때 모양이 달라질 수 있는 레이어 설정."""
    out = []
    if getattr(layer, "clipping", False):
        out.append("클리핑")
    blend = str(getattr(layer, "blend_mode", "")).split(".")[-1].lower()
    if blend not in ("normal", "pass_through", ""):
        out.append(f"합성 모드 {blend}")
    if getattr(layer, "has_effects", lambda: False)():
        out.append("레이어 효과")
    if layer.kind not in ("pixel", "group", "shape", "smartobject", "type"):
        out.append(f"종류 {layer.kind}")
    return out


def split(psd_path: Path, out_dir: Path, write: bool) -> tuple[list[str], list[str]]:
    """규칙을 보고, 틀린 곳이 하나도 없을 때만 조각을 쓴다."""
    from psd_tools import PSDImage

    errors: list[str] = []
    warnings: list[str] = []
    psd = PSDImage.open(psd_path)
    canvas = [psd.width, psd.height]
    results: list[tuple[str, dict, dict]] = []  # (인물, 조각 자리, 조각 그림)

    for top in psd:
        if not top.is_group():
            if top.is_visible():
                errors.append(f"'{top.name}': 맨 위에는 인물 폴더만 둔다(레이어를 폴더에 넣는다)")
            continue
        char = _norm(top.name)
        if not NAME_RE.match(char):
            errors.append(f"폴더 '{top.name}': 인물 이름은 영어 소문자·숫자·_ 만")
            continue
        parts: dict[str, dict] = {}
        images = {}
        z = 0

        def walk(group, prefix: list[str]) -> None:
            nonlocal z
            for layer in group:  # 아래에서 위 순서
                label = "/".join([top.name] + prefix + [layer.name])
                if not layer.is_visible():
                    warnings.append(f"'{label}': 숨긴 레이어라 건너뛴다")
                    continue
                if layer.is_group():
                    walk(layer, prefix + [_norm(layer.name)])
                    continue
                part = "_".join(prefix + [_norm(layer.name)])
                if not NAME_RE.match(part):
                    errors.append(f"'{label}': 부위 이름은 영어 소문자·숫자·_ 만 (지금 '{part}')")
                    continue
                if part in parts:
                    errors.append(f"'{label}': 부위 이름 '{part}'가 겹친다")
                    continue
                for p in _layer_problems(layer):
                    warnings.append(f"'{label}': {p} — 합쳐서 일반 레이어로 만들어 달라고 한다")
                img = layer.composite()
                if img is None or layer.width == 0 or layer.height == 0 or img.getbbox() is None:
                    warnings.append(f"'{label}': 빈 레이어라 건너뛴다")
                    continue
                img = img.convert("RGBA")
                parts[part] = {"x": layer.left, "y": layer.top, "w": img.width, "h": img.height, "z": z}
                images[part] = img
                z += 1

        walk(top, [])
        if not parts:
            errors.append(f"폴더 '{top.name}': 조각이 없다")
            continue
        print(f"{char}: 조각 {len(parts)}개 — {', '.join(parts)}")
        results.append((char, parts, images))

    if write and not errors:
        for char, parts, images in results:
            d = out_dir / char
            d.mkdir(parents=True, exist_ok=True)
            for old in d.glob(f"char_{char}_*.png"):
                if old.stem.removeprefix(f"char_{char}_") not in parts:
                    old.unlink()  # PSD에서 없어진 조각
            for part, img in images.items():
                img.save(d / f"char_{char}_{part}.png", optimize=True)
            meta = {"source": psd_path.name, "canvas": canvas, "parts": parts}
            (d / f"char_{char}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            print(f"  → {d.relative_to(ROOT) if d.is_relative_to(ROOT) else d}")
    elif write:
        print("틀린 곳이 있어 아무것도 쓰지 않았다.")
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("psd", type=Path)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--check", action="store_true", help="쓰지 않고 규칙만 본다")
    args = parser.parse_args()
    if args.psd.suffix.lower() == ".clip":
        print("FAIL  .clip은 읽지 않는다. 클립 스튜디오에서 .psd로 저장해서 받는다.")
        return 1
    errors, warnings = split(args.psd, args.out.resolve(), write=not args.check)
    for w in warnings:
        print(f"경고  {w}")
    for e in errors:
        print(f"FAIL  {e}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
