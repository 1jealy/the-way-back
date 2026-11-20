# 만든 사람과 빌려 온 것

외부 그림·소리·글꼴은 받을 때마다 여기에 적는다. 받기 전에 라이선스를 읽고 "AI 관련 사용 금지" 조항과 상업 사용 가능 여부부터 본다.

## 글꼴

| 파일 | 원본 | 만든 이 | 라이선스 | 받은 곳 | 고친 것 |
| --- | --- | --- | --- | --- | --- |
| `assets/fonts/noto_sans_kr_regular_subset.ttf` | Noto Sans KR (가변, `NotoSansKR[wght].ttf`) | Google, Adobe | [SIL Open Font License 1.1](assets/fonts/OFL.txt) | [google/fonts](https://github.com/google/fonts/tree/5bd87dfc525c8a0d1d8529d3684716e00c3fc59a/ofl/notosanskr) 커밋 `5bd87dfc` | 굵기 400 고정, 게임에서 쓰는 글자만 남김(`tools/font_subset.py`) |
| `assets/fonts/grandpa_hand_subset.ttf` (지도 할아버지 글씨) | Nanum Pen Script (`NanumPenScript-Regular.ttf`) | NHN Corporation, Sandoll Communication | [SIL Open Font License 1.1](assets/fonts/OFL_NanumPenScript.txt) | [google/fonts](https://github.com/google/fonts/tree/5bd87dfc525c8a0d1d8529d3684716e00c3fc59a/ofl/nanumpenscript) 커밋 `5bd87dfc` | 지도 문구 글자만 남김, 글꼴 이름을 "Way Back Grandpa Hand"로 바꿈(`tools/font_subset.py`) |
| `assets/fonts/hayun_hand_subset.ttf` (지도 하윤 글씨) | Gamja Flower (`GamjaFlower-Regular.ttf`) | YoonDesign Inc | [SIL Open Font License 1.1](assets/fonts/OFL_GamjaFlower.txt) | [google/fonts](https://github.com/google/fonts/tree/5bd87dfc525c8a0d1d8529d3684716e00c3fc59a/ofl/gamjaflower) 커밋 `5bd87dfc` | 지도 문구 글자만 남김, 글꼴 이름을 "Way Back Hayun Hand"로 바꿈(`tools/font_subset.py`) |

- 라이선스 확인(2026-11-19): 상업 사용·게임에 넣어 배포 가능. AI 관련 사용 금지 조항 없음. 글꼴만 따로 파는 것은 안 된다.
- 라이선스 확인(2026-11-20, 손글씨 둘): 둘 다 SIL OFL 1.1. 상업 사용·게임에 넣어 배포 가능. AI 관련 사용 금지 조항 없음.
- 원본의 예약 글꼴 이름(Reserved Font Name): Noto Sans KR은 "Source", Nanum Pen Script는 "Nanum", "NanumPen" 등(`OFL_NanumPenScript.txt` 첫 줄). 고친 글꼴에 이 이름을 쓰지 않는다. 그래서 손글씨 서브셋은 이름을 바꿨다(Gamja Flower는 예약 이름이 없지만 같이 맞춤).
- 저작권·라이선스 줄은 글꼴 파일 안(name 0, 13, 14)에 그대로 남아 있다.

## 소리

| 파일 | 원본 | 라이선스 |
| --- | --- | --- |
| `assets/audio/placeholder/*.ogg` | 코드로 만든 임시 소리(`tools/placeholder_sound.py`). 외부 에셋 아님 | 이 프로젝트 것 |

## 그림

| 파일 | 원본 | 라이선스 |
| --- | --- | --- |
| `assets/art/placeholder/**/*.png` | 코드로 그린 임시 배경(`tools/placeholder_art.py`). 외부 에셋 아님 | 이 프로젝트 것 |
| `assets/art/map/map_paper.jpg` | 할아버지 지도(최종본), 팀 일러스트 담당이 그림 | 이 프로젝트 것 |
