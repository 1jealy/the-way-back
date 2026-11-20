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
| 맡는 것 | 하윤 이동·조사, 하늘이 따라오기·부탁하기, 지도 화면, 퍼즐 로직, 진행 상태·저장, 장소 전환, 메뉴 | 장소 씬 배치, 패럴랙스·앞 층, 색 보정, 빛 알갱이·안개·물 반사, 바람 셰이더, 컷신 재생, 웹 내보내기·CI, 그림·소리 가져오기 도구 |
| 고치는 곳 | `project.godot`, `scripts/player/`, `scripts/dog/`, `scripts/ui/`, `scripts/game/`, `scenes/main.tscn`, `scenes/characters/`, `scenes/ui/`, `tests/` | `scenes/places/`(템플릿 제외), `shaders/`, `tools/`, `.github/`, `export_presets.cfg`, `assets/` |
| 건드리지 않는 곳 | `scenes/places/`의 배치 | `project.godot`, `scripts/`, `scenes/places/place_template.tscn` |

- **`project.godot`은 A만 고친다.** B가 오토로드·입력 키·설정이 필요하면 고치지 말고 PR 설명이나 이슈에 적어 A에게 넘긴다.
- **장소 씬 약속(아래)을 바꾸는 것은 A가 한다.** `place_template.tscn`과 `scripts/game/place.gd`가 약속 그 자체다.
- 상대 영역을 고쳐야 할 것 같으면 고치지 말고 이슈를 만든다.
- **지금(2026-11-19~)은 A 세션이 쉬고 있어서 B 세션이 A 영역도 맡는다**(사람이 정함). A 영역을 고친 PR에는 "A 대신 B 세션이 작업"이라고 적는다. A가 돌아오면 이 줄을 지우고, 그동안 바뀐 A 영역은 PR 목록으로 넘긴다.

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

- 하윤·하늘이는 장소 씬 안에 두지 않는다. `main.tscn`이 들고 있고 z 0이다. 그래서 z가 0보다 크면 하윤 앞, 작으면 뒤에 그려진다.
- **땅 높이 `Place.GROUND_Y` = 810**(화면 아래 1/4). 모든 장소에서 같다.
- 루트에서 정하는 값: `place_id`, `display_name`, `next_place`, `width`(장면표의 화면 길이 × 1920), `greybox`, `footstep_surface`(발소리 바닥), `footstep_changes`(`{x: 바닥}`, 그 x부터 바닥이 바뀜).
- 장소 소리는 장소 씬 `Sound/` 아래에 둔다(`Ambience` = 환경음, 그 밖 `AudioStreamPlayer2D` = 자리 소리). 버스는 씬에 적지 않는다 — `main`이 들어올 때 `Ambience` 버스로 보낸다(에디터에는 코드로 만든 버스가 없어 씬에 적으면 Master로 바뀐다).
- `greybox = true`면 `place.gd`가 회색 네모 배경을 만든다. 그림이 들어오면 끈다.
- 패럴랙스 층의 내용 폭은 `1920 + (width - 1920) × scroll` 이상이어야 끝까지 덮인다.

## 물리 층

| 층 | 이름 | 누가 |
| --- | --- | --- |
| 1 | world | 바닥·벽·발판 (StaticBody2D) |
| 2 | player | 하윤 |
| 3 | dog | 하늘이 (world와만 부딪힌다. 하윤과 안 부딪힌다) |
| 4 | gate | 막는 벽(Gate). **하윤만** 부딪힌다(하윤 마스크 = 1 + 4) |

하윤을 감지하는 Area2D(끝 지점, 부탁 자리, 조사 대상)는 `collision_layer = 0`, `collision_mask = 2`로 둔다. 그래야 하늘이나 바닥에 반응하지 않는다.

## 부탁 자리 (AskSpot)

하늘이에게 F로 부탁하는 자리. **B가 장소 씬에 놓고, 동작은 A가 만든다.**

- 장소 씬에 `Area2D`를 하나 놓고 `scripts/dog/ask_spot.gd`를 붙인다. 위치는 땅 위(y = 810). 충돌 모양은 스크립트가 `size`로 만든다(자식 노드 필요 없음).
- 이름은 장면표 번호로: `AskSpot_3-5`.

| 속성 | 뜻 |
| --- | --- |
| `action` | `FETCH` 가져와 / `SNIFF` 냄새 / `HOLD` 기다려 |
| `size` | 하윤이 이 안에 있어야 F가 먹는다 (기본 320x300) |
| `target_offset` | 하늘이가 가는 곳, 자리 기준 (x만 쓴다) |
| `grants_flag` | 행동의 핵심 순간에 세우는 플래그 (예: `station_key`) |
| `release_offset` | HOLD에서, 하윤이 target보다 이만큼 오른쪽으로 가면 하늘이가 놓고 따라온다 |
| `lines` | 하늘이가 돌아와 부탁이 끝나면 대사 상자에 띄울 줄(3-5 "하윤: 고마워.") |

- 신호: `started`(출발) / `acted`(물었다·짖었다·버티기 시작) / `completed`(돌아왔다). 퍼즐 반응(문이 열린다, 길이 열린다)은 `grants_flag`나 이 신호를 받아 만든다.
- 한 번 쓰면 다시 안 먹는다(`one_shot`).
- 가져와·냄새 동안에는 하윤 조작이 멈춘다. 기다려는 하윤이 움직일 수 있다.

## 조사 대상 (Interactable)

E로 조사하는 물건·글. **B가 장소 씬에 놓고, 동작은 A가 만든다.**

- 장소 씬에 `Area2D`를 하나 놓고 `scripts/game/interactable.gd`를 붙인다. 위치는 땅 위(y = 810). 충돌 모양과 `[E] …` 안내는 스크립트가 만든다.
- 이름은 장면표 번호와 물건으로: `Look_1-3_Album`.

| 속성 | 뜻 |
| --- | --- |
| `prompt` | 안내 문구. 앞에 `[E] `가 붙는다 (기본 "살펴보기") |
| `size` | 하윤이 이 안에 있어야 조사할 수 있다 (기본 200x300) |
| `lines` | 대사 상자에 띄울 줄. `하윤: 고마워.`는 대사(이름이 뜬다), 콜론 없는 줄은 글·지문 |
| `grants_flag` | 조사하면 세우는 플래그 |
| `requires_flag` | 이 플래그가 서 있을 때만 조사할 수 있다 |
| `one_shot` | 한 번 조사하면 다시 안 된다 |
| `show_locked` | `requires_flag`가 서기 전에도 안내가 뜨고, 조사하면 잠긴 소리(`sfx_locked_`)만 난다(잠긴 서랍·문). 신호 `locked` |
| `sound` | 조사할 때 낼 소리 이름 앞머리(예: `sfx_pickup_`) |

- 신호: `interacted`(조사 시작) / `finished`(대사를 다 넘김). 다음 연출은 `finished`를 기다린다(고정 시간으로 기다리지 않는다).
- 여러 개가 겹치면 하윤에게 가장 가까운 것 하나만 안내가 뜬다.
- 대사는 장면표(`docs/story.md`)의 "글·대사" 칸에 있는 것만 쓴다. 새 대사를 넣으려면 장면표부터 고친다.

## 막는 벽 (Gate)과 옮겨 가기 (Passage)

진행을 막는 곳. **B가 장소 씬에 놓고, 동작은 A가 만든다.** 원점은 땅 위(y = 810).

- **Gate**: `StaticBody2D` + `scripts/game/gate.gd`. 이름 `Gate_<장면>`. `opens_on_flag`가 서면 사라진다(비우면 늘 막는다). 물리 층 4라 **하윤만 막고 하늘이는 지나간다**(징검다리 첫 돌에 하늘이가 가야 한다). 플래그는 `GameState.flag_changed`로 듣고, 이어하기 때는 처음부터 열려 있다.
  - 막는 벽의 플래그를 세우는 부품은 그 벽보다 왼쪽(또는 앞 장소)에 있어야 한다(스모크 검사가 본다).
  - 지금 놓인 것: 집 대문 `Gate_1-6`(`has_map`), 대합실 문 `Gate_3-6`(`station_door_open`), 징검다리 `Gate_5-3`(`river_stone_held`), 끊긴 철교 `Gate_6-2`(늘 막음).
  - 숲 4-2 빛 갈림길 두 번: 갈림길마다 냄새 부탁 `AskSpot_4-2_N` + 빛줄기 셋 `Look_4-2_LightNM`(Passage, 맞는 빛은 다음으로, 틀린 빛은 이끼 바위 앞으로) + 늘 막는 `Gate_4-2_N`. 빛줄기 자리는 임시 배경(`tools/placeholder_art.py` `FOREST_FORKS`)과 같다.
- **Passage**: `Area2D` + `scripts/game/passage.gd`(조사 대상을 이은 것). 조사하면 화면이 어두워졌다 밝아지며 하윤이 같은 장소의 `to_x`로 옮겨 간다(`main.move_player_to`). 바닥 높이로 이어지지 않는 길에 쓴다. 지금은 철교 `Look_6-3_Slope`(냄새 뒤 강둑으로 내려가기).

## 벤치 (BenchSit)

`Area2D` + `scripts/game/bench_sit.gd`(조사 대상을 이은 것). 이름 `Sit_<장면>`, 벤치 가운데 땅 위.

- `auto_sit = true`(3-3): 하윤이 들어오면 저절로 `sit_seconds`(15초) 앉는다. 그동안 장소 층이 `tint`로 물들고 환경음이 `ambience_duck_db`만큼 줄고, 끝 무렵 `end_sound`. 다 앉으면 `grants_flag`(`station_sat`)를 세우고 일어난다. 안내 글 없음.
- `auto_sit = false`(2-5): "[E] 앉기" → 방향키나 E로 일어난다. 조작 잠금 이유 `sit`.
- 하늘이 만남은 `appears_on_flag`(`station_sat`)가 서야 하늘이가 나타난다. 그래서 3-3 벤치는 만남 자리보다 왼쪽, 알아채는 거리(360px) 밖에 둔다.

## 엔딩 (나루터 7-3 ~ 7-7)

- **할아버지** `scenes/characters/grandpa.tscn`(`Grandpa`): B가 나루터 씬에 놓는다(`Grandpa_7-3`, 배 옆 땅 위). `appears_on_flag`(`map_circle_5`)가 서면 천천히 나타난다. `raise_camera()`/`lower_camera()`. 걷지 않는다(기획서).
- **엔딩 연출** `scripts/game/ending.gd`(`EndingDirector`): 할아버지 옆에 놓는다(`Ending_7-3`). 다섯째 동그라미 뒤 하윤이 `trigger_distance`(380px) 안으로 오면 시작하고 끝까지 조작을 막는다(잠금 이유 `ending`).
  하윤이 달려가다 멈춤(`player.auto_move_to`) → 하늘이가 먼저 할아버지에게(`dog.script_move_to`) → "할아버지: 왔니." → 컷신 1(팔찌) → 하늘이가 발치에 앉고 셔터(`ending_photo`) → 강 위 구간으로(`crossing_scene`).
- **7-1 안개** `scripts/game/mist_reveal.gd`(`MistReveal`, 나루터 `Mist_7-1`): 들어서면 하얀 안개가 걷히고 휘파람 선율이 작게 시작된다.
- **7-6 강 위 구간** `scenes/places/crossing.tscn`(place_id `crossing`, 지도에는 없음) + `scripts/game/boat_ride.gd`(`BoatRide_7-6`): 셋이 탄 배가 `ride_seconds`(70초) 동안 저절로 흘러간다(조작 없음, 잠금 `ending`). 강 건너 안개에 지나온 장소 다섯이 차례로 비친다(각 장소의 `bg_<장소>_mid` 그림을 `shaders/ghost.gdshader`로 바래게 — 진짜 그림이 오면 그것이 비친다). 물에 비친 셋은 또렷하다(모습을 뒤집어 복사). 하윤이 물을 한 번 만진다. 휘파람 선율을 처음부터 끝까지(`restart`) → 컷신 2(`cut_boat`, 하얗게 번짐) → 제목 → `ending_seen` → 타이틀로(`return_to_title`, 검사는 끈다).
- **음악**: `main.play_music(이름, dB, 페이드, restart)` / `fade_music` / `stop_music`. 장소를 옮겨도 끊기지 않는다(`Music` 버스).
- **컷신 재생** `scripts/ui/cutscene_player.gd`(`CutscenePlayer`, B): 한 장짜리 그림에 천천히 확대·이동, 글자는 글꼴로 얹는다(팔찌 "이하윤 / 9세"). 그림은 이름(`cut_bracelet`)으로 `assets/art` 아래에서 찾고 진짜 그림이 placeholder보다 먼저다. 대사 상자보다 아래 층(5)이라 컷신 위로 대사가 보인다.
- 나루터 `Gate_7-3`(`map_circle_5`): 다섯째 동그라미 전에는 할아버지 쪽으로 못 간다.

## 대사 상자 (DialogueBox)

- `scenes/ui/dialogue_box.tscn`, `main.tscn`의 `Overlay` 아래. 그룹 `dialogue_box`로 찾는다.
- `play(lines)` → 한 줄씩 글자가 찍히고(초당 30자) E로 넘긴다 → 다 넘기면 `finished`.
- 열려 있는 동안 하윤 조작을 막는다.

## 지도 (MapScreen)

- `scenes/ui/map_screen.tscn` + `scripts/ui/map_screen.gd`(펼치기·접기·체크), `scripts/ui/map_canvas.gd`(그리기), `scripts/game/map_data.gd`(자리·메모).
- `has_map` 플래그가 서야 M이 먹는다 → 1-5의 서랍 조사 대상에 `grants_flag = has_map`을 준다.
- `has_map`이 서면 화면 왼쪽 위에 "[M] 지도"가 뜨고, 처음 펼치면(`map_opened` 플래그) 사라진다(장면표 1-5 "M 안내").
- **동그라미 체크는 조사 대상의 `map_circle`(1~5)** 로 한다. E → 지도가 펼쳐지고 그 동그라미에 체크 → 하윤이 접으면 그 조사 대상의 `lines`가 나온다. 플래그 `map_circle_1`~`map_circle_5`. 장면 2-2, 3-1, 4-3, 5-4, 7-2.
- 지나온 길은 지금 장소의 `place_id`와 그 안에서의 위치로 그린다. 새 장소를 만들면 `MapData.PLACES`에도 넣어야 지도에 나온다.
- 메모 문구는 `map_data.gd` 한 곳에 있다. 고치면 `docs/design.md` "지도의 다섯 동그라미" 표도 같이 고친다(글꼴 도구가 둘 다에서 글자를 모은다).
- **지도 그림**: `MapData.PAPER_ART`(`assets/art/map/`)가 있으면 그 그림을 `PAPER_RECT`(1740×980)에 깔고, 코드는 접힌 자국·강·철교·작은 기호·배를 그리지 않는다. 동그라미·메모·체크·지나온 길·장소 이름은 코드가 그린다(그림 위에서는 종이색 테두리). 길과 가지 않는 길은 그림에 아직 없어서 코드가 그린다 — 그림에 들어오면 `_draw_route`·`_draw_side_roads`도 끈다. 좌표는 그림에 맞춰 `map_data.gd`만 고친다.
- 지금 그림은 일러스트 담당의 **미리보기**(1080×608 JPEG)다. 최종본(1920×1080 이상 PNG)이 오면 파일만 바꾸고 좌표를 다시 맞춘다.

## 저장·타이틀

- 시작 씬은 타이틀(`scenes/ui/title_screen.tscn`): "이어하기"(저장이 없으면 꺼짐) / "처음부터".
- **장소에 들어갈 때 자동 저장**(`main._swap_place` → `GameState.save_game`). 저장하는 것은 그 장소 씬과 그 순간의 플래그뿐이다. 이어하기는 그 장소 처음부터 한다.
  그래서 **장소 안의 진행은 플래그로 남겨야** 이어하기 뒤에도 유지된다(조사 대상 `grants_flag`, 부탁 자리 `grants_flag`, 지도 `map_circle_N`, `dog_joined`).
- 저장 파일 `user://save.cfg`. 헤드리스(검사·CI)에서는 자동 저장이 꺼져 있다(`GameState.autosave`). 저장을 시험하는 검사는 `save_path`를 바꾸고 켠다.

## 일시정지 메뉴

- `scenes/ui/pause_menu.tscn`, Esc(`pause`). 열면 `get_tree().paused = true`로 게임 전체가 멈추고 메뉴만 돈다(`PROCESS_MODE_ALWAYS`).
- "계속하기" / Esc → 풀림. "타이틀로" → 멈춤을 풀고 타이틀로.
- 지도가 펼쳐져 있으면 지도가 Esc를 먼저 가져간다(지도의 `_input`). 새로 Esc를 쓰는 화면을 만들면 같은 방식으로 `_input`에서 가져갈 것.
- 멈춘 동안에도 돌아야 하는 것(메뉴 소리 등)만 `PROCESS_MODE_ALWAYS`로 둔다. 연출용 `create_timer`는 멈춘 동안에도 흐르므로(기본값) 본편 연출에는 `create_timer(t, false)`를 쓴다.

## 소리

- 이름 규칙·도구는 `assets/audio/README.md`. 파일은 `SoundBank`(`scripts/game/sound_bank.gd`)로 이름으로 찾는다: `SoundBank.pick("step_wood_")`는 step_wood_NN 중 하나(바로 앞과 다른 것). 진짜 소리가 placeholder보다 먼저다.
- 버스: `Master` / `Ambience`(장소 소리) / `Sfx`(발소리·효과음) / `Music`. `GameState`가 시작할 때 `bus_count`로 만든다(`add_bus()` 금지, 아래 #877).
- 장소를 옮길 때 `Ambience` 버스가 화면 페이드와 같이 줄었다 커진다(`main._fade_to`).
- 하윤 발소리는 110px마다, 바닥은 장소의 `surface_at(x)`. 하늘이 발톱은 **간이역·숲에서만**(`Dog.CLAW_PLACES`, 장면표 복선).

## 하윤 조작 잠금

- `player.lock(이유)` / `player.unlock(이유)`. 이유가 하나라도 남아 있으면 걷지도 조사하지도 않는다.
- 쓰는 이유: `place_change`(장소 전환), `dog_task`(하늘이 가져와·냄새), `dialogue`(대사 상자), `meeting`(하늘이 만남), `map`(지도), `sit`(벤치), `ending`(엔딩). 새로 막을 일이 생기면 새 이유 이름을 쓴다 — 남의 이유를 풀지 않는다.

## 하늘이

- `scenes/characters/dog.tscn` + `scripts/dog/dog.gd`. 하윤처럼 `main.tscn`이 들고 있다.
- 합류 전에는 보이지 않는다. 합류는 만남 부품(아래)이 시킨다. 코드로는 `dog.join(player)`이고 `dog_joined` 플래그를 세운다.

### 하늘이 만남 (DogMeeting, 장면표 3-4)

- **B가 간이역 씬의 3-4 자리에 놓는다.** `Node2D`에 `scripts/dog/dog_meeting.gd`를 붙이고 땅 위(y = 810)에 둔다. 이름은 `DogMeeting_3-4`.
- 하늘이가 그 자리에 앉아 있다 → 하윤이 다가가면 두 번 물러난다(`retreats`, `retreat_distance`) → 세 번째에 `[E] 쪼그려 앉기` → 하윤이 쪼그려 앉고 하늘이가 다가옴 → 이름표 글 "하늘", "하윤: 하늘이…?" → 합류.
- 물러날 자리가 장소 안에 있어야 한다: 놓는 자리 + `retreats × retreat_distance`(기본 600px)가 장소 끝 지점보다 왼쪽이어야 한다.
- 3-5의 첫 부탁 자리(가져와)는 이 자리보다 오른쪽에 둔다. 합류 전에는 F가 먹지 않는다.
- 이미 합류했으면 아무 일도 하지 않는다. 만남 중에 장소를 떠나면 하늘이는 다시 숨는다.
- 하윤 뒤 80~120px, 멈추면 2초 뒤 앉는다. 장소를 옮기면 하윤 뒤에 다시 선다(하던 부탁은 취소).
- **힌트**: 하윤이 조작할 수 있는 채로 8초 가만히 있으면, 하늘이가 다음 목표 쪽으로 최대 160px 앞서 가서 1.5초 바라보다 돌아온다(같은 정지 동안 한 번).
  다음 목표 = 하윤보다 오른쪽의, 아직 안 쓴 부탁 자리 · `map_circle` 조사 대상 · `one_shot` 조사 대상 중 가장 가까운 것. 없으면 장소 끝 지점.
  그래서 **진행에 필요한 조사 대상은 `one_shot`으로** 두면 힌트가 가리킨다(되풀이 조사용 분위기 대상은 안 가리킨다).

## 하윤

- `scenes/characters/player.tscn` + `scripts/player/player.gd`. 원점은 발밑, 키는 약 250px.
- 걷는 속도 250px/초 = 화면 하나를 약 7.7초(#29에서 200 → 250). 장소 폭은 200 기준으로 잡았다. 속도를 또 바꾸면 장면표 시간도 다시 본다.

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
- 오디오 버스는 `AudioServer.add_bus()` 대신 `bus_count`를 늘려 만든다. 4.6.2 웹에서 `add_bus()`가 출력을 끊었다(방과 후 #877). **4.7.2 웹에서도 똑같이 끊긴다**(#34에서 웹 빌드로 확인: `add_bus()` 버스는 출력 0, `bus_count` 버스는 정상).
- 부드러운 그라데이션 그림은 손실 압축·VRAM 압축을 걸지 않는다(색 띠가 생긴다).
- 그림·소리 외부 에셋은 받을 때 라이선스를 읽고 `CREDITS.md`에 적는다. "AI 관련 사용 금지" 조항부터 본다.

## 검증

푸시 전에 돌린다. Godot 바이너리 경로는 각자 환경에 맞춘다.

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/smoke_test.gd      # 뼈대·장소 (B가 더한다)
godot --headless --path . --script res://tests/gameplay_test.gd   # 게임플레이 (A가 더한다)
```

종료 코드 0이면 통과다. 검사 스크립트에서는 `Dog`·`AskSpot` 같은 `class_name`을 직접 쓰지 않는다. 검사 스크립트가 컴파일될 때는 오토로드(`GameState`)가 아직 없어서, 그걸 쓰는 스크립트까지 같이 컴파일되다 실패한다. 실행 중에 `load()`로 불러 쓴다(`tests/gameplay_test.gd` 참고).

- 스모크 검사 로그에서 `SCRIPT ERROR`, `Parse Error`, `FAIL`을 찾는다. 파싱 오류에도 종료 코드가 0일 수 있다.
- 새 동작을 넣으면 맡은 쪽 검사 스크립트에 검사를 더한다. 일부러 깨뜨려서 검사가 실패하는지도 한 번 본다.
- 화면을 봐야 하면 가상 화면에서 스크린샷을 찍는다: `xvfb-run -a godot --path . --rendering-method gl_compatibility --script <찍는 스크립트>`.
- 손맛·화면·소리 최종 확인은 사람 몫이다.
