# 돌아가는 길 (The Way Back)

할아버지의 지도를 따라 늙은 개와 함께 걷는 30분짜리 횡스크롤 어드벤처. 액션·실패·분기 없음, 엔딩 하나.
2인 팀(개발 1, 일러스트 1). Claude 세션 두 개가 개발을 나눠 맡는다.

**작업 전에 읽을 것**: `docs/design.md`(기획서, 기준 문서), `docs/story.md`(장면표 — 장면마다 화면·복선·소리·그림·시간).
두 문서와 어긋나는 구현을 하지 않는다. 문서를 바꿔야 하면 그 PR에서 문서도 같이 고친다.

## 엔진

- **Godot 4.7.2 고정.** 4.8이 나와도 올리지 않는다.
- 렌더러: 데스크톱 Forward+, 웹은 Compatibility로 내보낸다.
- 기준 화면 1920x1080, `canvas_items` 늘이기, 비율 유지.

## 담당 나누기

| | A: 게임플레이 | B: 월드·연출·도구 |
| --- | --- | --- |
| 맡는 것 | 하윤 이동·조사, 구름이 따라오기·부탁하기, 지도 화면, 퍼즐 로직, 진행 상태·저장, 장소 전환, 메뉴 | 장소 씬 배치, 패럴랙스·앞 층, 색 보정, 빛 알갱이·안개·물 반사, 바람 셰이더, 컷신 재생, 웹 내보내기·CI, 그림·소리 가져오기 도구 |
| 고치는 곳 | `project.godot`, `scripts/player/`, `scripts/dog/`, `scripts/ui/`, `scripts/game/`, `scenes/main.tscn`, `scenes/characters/`, `scenes/ui/` | `scenes/places/`(템플릿 제외), `shaders/`, `tools/`, `.github/`, `export_presets.cfg`, `assets/` |
| 건드리지 않는 곳 | `scenes/places/`의 배치 | `project.godot`, `scripts/`, `scenes/places/place_template.tscn` |

- **`project.godot`은 A만 고친다.** B가 오토로드·입력 키·설정이 필요하면 고치지 말고 PR 설명이나 이슈에 적어 A에게 넘긴다.
- **장소 씬 약속(아래)을 바꾸는 것은 A가 한다.** `place_template.tscn`과 `scripts/game/place.gd`가 약속 그 자체다.
- 상대 영역을 고쳐야 할 것 같으면 고치지 말고 이슈를 만든다.

## 작업 규칙

- **이슈 하나 = 브랜치 하나 = PR 하나.** 브랜치 이름 `issue-<번호>-<짧은 주제>`. PR 본문에 `Closes #<번호>`.
- 시작 전에 항상 최신 `main`을 받는다. PR은 작게 자주.
- PR 본문에는 실제로 확인한 것(아래 검증)과 확인하지 못한 것(손맛·화면·소리는 사람이 직접 해 봐야 한다)을 나눠 적는다.
- `.gd`를 새로 만들면 Godot이 `.gd.uid`를 만든다. 같이 커밋한다. 새 그림·소리는 `.import`도 같이 커밋한다.

## 장소 씬 약속

장소 하나 = 씬 하나(`scenes/places/<place_id>.tscn`). **`place_template.tscn`을 상속해서** 만든다.

```text
<Place>  (place.gd)
├─ Layers
│  ├─ Sky    Parallax2D  scroll 0.1   z -40   하늘
│  ├─ Far    Parallax2D  scroll 0.3   z -30   먼 산·먼 숲
│  ├─ Mid    Parallax2D  scroll 0.6   z -20   중간 풍경
│  ├─ Ground Node2D      scroll 1     z -10   하윤이 걷는 땅
│  ├─ Props  Node2D      scroll 1     z -5    하윤 뒤에 있는 물건(정류장, 벤치)
│  └─ Front  Parallax2D  scroll 1.25  z 10    하윤 앞을 지나가는 것(억새, 나무 기둥)
├─ Spawn     Marker2D    하윤이 서는 곳
├─ Exit      Area2D      닿으면 다음 장소로 (자리는 width에 맞춰 자동)
├─ Bounds    Floor / LeftWall / RightWall (크기는 width에 맞춰 자동)
└─ Markers   장면 위치 표시. 이름은 장면표 번호(예: "2-3")
```

- 하윤·구름이는 장소 씬 안에 두지 않는다. `main.tscn`이 들고 있고 z 0이다. 그래서 z가 0보다 크면 하윤 앞, 작으면 뒤에 그려진다.
- **땅 높이 `Place.GROUND_Y` = 810**(화면 아래 1/4). 모든 장소에서 같다.
- 루트에서 정하는 값: `place_id`, `display_name`, `next_place`, `width`(장면표의 화면 길이 × 1920), `greybox`.
- `greybox = true`면 `place.gd`가 회색 네모 배경을 만든다. 그림이 들어오면 끈다.
- 패럴랙스 층의 내용 폭은 `1920 + (width - 1920) × scroll` 이상이어야 끝까지 덮인다.

## 하윤

- `scenes/characters/player.tscn` + `scripts/player/player.gd`. 원점은 발밑, 키는 약 250px.
- 걷는 속도 200px/초 = 화면 하나를 약 10초. 장면표의 시간 어림이 이 속도 기준이다. 바꾸면 장면표 시간도 다시 본다.

## 입력

| 액션 | 키 |
| --- | --- |
| `move_left` / `move_right` | A D, ← → |
| `interact` | E |
| `ask_dog` | F |
| `open_map` | M |
| `pause` | Esc |

**글자 키는 `physical_keycode`로 묶는다.** 웹판에서 한글 입력기가 켜져 있으면 `keycode`로 묶은 글자 키가 먹지 않는다(방과 후 #874).

## 지켜 온 것 (방과 후에서 배운 것)

- 연출을 고정 시간(`await` 2.5초)으로 기다리지 않는다. 대사·애니메이션이 끝났다는 신호로 맞춘다.
- 게임 문구에 이모지를 쓰지 않는다. 한글 글꼴은 쓰는 글자만 남긴 서브셋으로 넣는다(웹에는 OS 글꼴이 없다).
- 오디오 버스는 `AudioServer.add_bus()` 대신 `bus_count`를 늘려 만든다. 4.6.2 웹에서 `add_bus()`가 출력을 끊었다(방과 후 #877). 4.7.2에서 고쳐졌는지 확인 전까지 이렇게 한다.
- 부드러운 그라데이션 그림은 손실 압축·VRAM 압축을 걸지 않는다(색 띠가 생긴다).
- 그림·소리 외부 에셋은 받을 때 라이선스를 읽고 `CREDITS.md`에 적는다. "AI 관련 사용 금지" 조항부터 본다.

## 검증

푸시 전에 돌린다. Godot 바이너리 경로는 각자 환경에 맞춘다.

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/smoke_test.gd   # 종료 코드 0이면 통과
```

- 스모크 검사 로그에서 `SCRIPT ERROR`, `Parse Error`, `FAIL`을 찾는다. 파싱 오류에도 종료 코드가 0일 수 있다.
- 새 동작을 넣으면 `tools/smoke_test.gd`에 검사를 더한다. 일부러 깨뜨려서 검사가 실패하는지도 한 번 본다.
- 화면을 봐야 하면 가상 화면에서 스크린샷을 찍는다: `xvfb-run -a godot --path . --rendering-method gl_compatibility --script <찍는 스크립트>`.
- 손맛·화면·소리 최종 확인은 사람 몫이다.
