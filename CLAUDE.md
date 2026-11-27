# 돌아가는 길 (The Way Back)

할아버지의 지도를 따라 늙은 개와 함께 걷는 15분짜리 횡스크롤 어드벤처(처음 30분에서 2026-11-24에 줄임). 액션·실패·분기 없음, 엔딩 하나.
배경은 **유럽 동화풍 시골**(2026-11-27에 한국 시골에서 바꿈, #136 — 기획서 "배경 방향" 표). 게임 문구와 인물 이름은 한국어 그대로.
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
│  └─ Front  Parallax2D  scroll 1.25  z 10    하윤 앞을 지나가는 것(들풀, 나무 기둥)
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
| `pickup_art` | 주운 물건 그림 이름(예: `prop_key`). 조사하면 그 그림이 대상 위로 떠올랐다 사라진다(1.4초, 조작은 안 막는다). 대사 없이 "주웠다"를 보여 줄 때 |
| `album_art` | 펼친 앨범 그림 이름(1-3 `album_open`). 있으면 조사할 때 `AlbumView`가 그림을 `album_pages`(3)쪽으로 나눠 한 쪽씩 보여 준다(E·→ 다음, ← 앞, 마지막 쪽에서 E 또는 Esc로 덮음, 잠금 `album`). 덮은 뒤에 `lines` |
| `cutscene_art` | 손그림 컷신 그림 이름(1-5 서랍 `cut_map`, #135). 있으면 조사할 때 `CutscenePlayer`로 컷신을 띄우고(`cutscene_zoom`·`cutscene_pan_to`·`cutscene_seconds`, 잠금 `cutscene`) 그 위로 `lines`를 보여 준 뒤 걷힌다. `grants_flag`는 컷신이 걷힌 뒤에 세운다([M] 지도 안내가 컷신 위에 겹치지 않게) |
| `show_locked` | `requires_flag`가 서기 전에도 안내가 뜨고, 조사하면 잠긴 소리(`sfx_locked_`)만 난다(잠긴 서랍·문). 신호 `locked` |
| `sound` | 조사할 때 낼 소리 이름 앞머리(예: `sfx_pickup_`) |

- 신호: `interacted`(조사 시작) / `finished`(대사를 다 넘김). 다음 연출은 `finished`를 기다린다(고정 시간으로 기다리지 않는다).
- 여러 개가 겹치면 하윤에게 가장 가까운 것 하나만 안내가 뜬다.
- 대사는 장면표(`docs/story.md`)의 "글·대사" 칸에 있는 것만 쓴다. 새 대사를 넣으려면 장면표부터 고친다.

## 막는 벽 (Gate)과 옮겨 가기 (Passage)

진행을 막는 곳. **B가 장소 씬에 놓고, 동작은 A가 만든다.** 원점은 땅 위(y = 810).

- **Gate**: `StaticBody2D` + `scripts/game/gate.gd`. 이름 `Gate_<장면>`. `opens_on_flag`가 서면 사라진다(비우면 늘 막는다). 물리 층 4라 **하윤만 막고 하늘이는 지나간다**(징검다리 첫 돌에 하늘이가 가야 한다). 배경에 막는 물건이 없는 곳은 `art`(그림 이름)를 주면 막는 동안 하윤 앞(`art_z` 5)에 그린다(숲 `Gate_4-2_N`의 `prop_thicket`). 투명한 벽은 왜 못 가는지 안 보여서 막힌 줄 모른다. 플래그는 `GameState.flag_changed`로 듣고, 이어하기 때는 처음부터 열려 있다.
  - 막는 벽의 플래그를 세우는 부품은 그 벽보다 왼쪽(또는 앞 장소)에 있어야 한다(스모크 검사가 본다).
  - 지금 놓인 것: 집 대문 `Gate_1-6`(`has_map`), 들판 `Gate_2-3`(`map_caught`, 날아간 지도), 대합실 문 `Gate_3-6`(`station_door_open`), 징검다리 `Gate_5-3`(`river_stone_held`), 끊긴 철교 `Gate_6-2`(늘 막음).
  - 숲 4-2 빛 갈림길 두 번: 첫째는 냄새 부탁 `AskSpot_4-2_1`, 둘째는 나무 피리(`Keepsake_4-2_Flute`) + 선율 따라 불기(`FluteEcho_4-2`, #113) + 덤불 벽 입구 셋 `Look_4-2_LightNM`(Passage, `[E] 왼쪽/가운데/오른쪽 입구로 들어가기` — 셋이 같은 말이면 어느 입구 앞인지 몰랐다(#109), 맞는 입구는 다음으로, 틀린 입구는 이끼 바위 앞으로) + 늘 막는 `Gate_4-2_N`(덤불 그림). 덤불 벽과 입구는 임시 배경 props 층에 그린다. 빛줄기 자리는 임시 배경(`tools/placeholder_art.py` `FOREST_FORKS`)과 같다.
- **Passage**: `Area2D` + `scripts/game/passage.gd`(조사 대상을 이은 것). 조사하면 화면이 어두워졌다 밝아지며 하윤이 같은 장소의 `to_x`로 옮겨 간다(`main.move_player_to`). `fallback_until_flag`가 서기 전에는 `fallback_to_x`로 간다(숲 둘째 갈림길의 맞는 입구 `Look_4-2_Light23`: 피리로 따라 불기 전에는 이끼 바위 앞으로). 바닥 높이로 이어지지 않는 길에 쓴다. 지금은 철교 `Look_6-3_Slope`(손전등으로 디딤돌을 찾거나 냄새 부탁 뒤 강둑으로 내려가기).

## 작은 순간 (Moment)

`Node2D` + `scripts/game/moment.gd`. 걷기만 하는 빈 구간에 **대사 없이** 지나가는 연출. 장면표 "빈 구간의 작은 순간" 표가 목록이다.

- 하윤이 원점 - `trigger_before`를 지나면 한 번 일어난다. 처음 알아챘을 때 이미 원점 + `trigger_window`(600px)보다 멀리 가 있으면(옮겨 가기·순간이동) 일어나지 않고 지나간 것으로 친다. 플래그를 세우지 않는다(진행과 상관없고, 이어하기 뒤엔 다시 일어난다).
- 필요한 것만 채운다: 하늘이 `dog_to`(원점 기준 x)·`dog_hold`·`dog_look`(합류 전이거나 부탁 중이면 건너뜀) / 하윤 `player_pause`·`player_look`(잠금 이유 `moment`) / 그림 `art`가 `art_from` → `art_to`로 `art_seconds` 동안 지나간다(`art_z`, `art_scale`, `art_count`, `art_bob`). 그림은 오른쪽을 보고 그리고, 왼쪽으로 가면 뒤집힌다.
- 하늘이 연출은 `dog.script_move_to` → `dog.look(dir)` → `dog.release_script`.
- 이름 `Moment_<장면>_<내용>`. 지금 놓인 것: 들판 `Moment_2-4_Dragonflies`, 간이역 `Moment_3-6_Sniff`·`Moment_3-6_Lead`, 숲 `Moment_4-1_Deer`, 강가 `Moment_5-2_Paw`(물그림자 `Reflection_5-2` 안: 비친 하윤 옆에 비치지 않는 하늘이)·`Moment_5-4_Heron`, 철교 `Moment_6-1_Creak`·`Moment_6-3_LookBack`.

## 날아간 지도 (MapChase, 장면표 2-3 퍼즐 2)

`Node2D` + `scripts/game/map_chase.gd`. 들판에 `MapChase_2-3`(땅 위 x 4300)과 그 오른쪽 `Gate_2-3`(`map_caught`, x 7000).

- 지도를 가진(`requires_flag` = `has_map`) 하윤이 원점을 지나면 센 바람(`sfx_wind_gust_`)에 지도가 날아가고 "하윤: 어? 기다려!"(그동안 잠금 `map_chase`).
- 지도는 `stops`(원점 기준 x)에 차례로 걸린다. 들판은 #111부터 **하나**(1600 → x 5900): 한 번에 멀리 날아가 `reveal_flag`(`kite_flown`)가 서기 전까지 들풀 속에 묻힌다(`buried`, 안 보이고 줍지도 못한다). 연 날리기가 끝나면 반짝이며 보이고 `[E] 지도 줍기` → `grants_flag`(`map_caught`) → 벽이 열린다. `reveal_flag`를 비우면 예전처럼 덤불마다 다시 날아가다 마지막에서 줍는다.
- 날아가 있는 동안 `MapScreen.away = true`: M이 먹지 않고 `map_circle` 조사 대상도 안 뜬다.
- 덤불 자리는 임시 배경 `tools/placeholder_art.py` `FIELD_SNAGS` 중 하나여야 한다(스모크 검사). 그림은 `prop_map_folded`.
- 이어하기는 장소 처음부터라, 줍기 전에 끄면 다시 쫓는다.

## 할아버지 물건 (Keepsake)과 미니게임 (MiniGame, #111)

기획서 "할아버지의 물건과 미니게임"이 목록이다. 물건 다섯(손전등·마름모 연·회중시계·나무 피리·돌 주머니), 미니게임 넷(들판 연·숲 피리·강가 물수제비(선택)·철교 손전등). 장소마다 형태가 다르다.

- **Keepsake**: `Area2D` + `scripts/game/keepsake.gd`(조사 대상을 이은 것). 이름 `Keepsake_<장면>_<물건>`. `item`(`Keepsake.ITEMS`의 열쇠)의 그림이 땅에 놓여 보이고(`art_offset`, `art_rotation`), E로 주우면 하윤이 무릎을 굽혀 숙여 손이 땅까지 닿게 집고(`player.play_pickup()`, `HayunRig.PICKUP_KEYS`, 잠깐 잠금 `pickup`, #114) 그림이 손에 들려 올라온 뒤 빛에 싸여 머리 위로 떠올랐다 사라진다. 플래그 `item_<item>`(`Keepsake.flag_for`). 지금 놓인 것: 집 `Keepsake_1-6_Flashlight`(마당 x 4900, 여기서는 안 쓴다), 들판 `Keepsake_2-3_Kite`, 숲 `Keepsake_4-2_Flute`(첫 갈림길 뒤 x 4600), 강가 `Keepsake_5-4_Pouch`(x 6050).
- **MiniGame**: `scripts/game/minigame.gd`. UI를 화면 안에 녹이는 공통 부품 — 하윤 잠금(이유 `minigame`), 손 옆 작은 키 안내(`show_key_hint(["E"], "꾹 누르면 감기")`, 처음 누르면 사라진다. 손이 몸 뒤로 가도 몸에 겹치지 않게 늘 하윤 앞쪽), 어긋남(`miss()`) → `help_after`(3)번이면 `help`(빛이 넓어지거나 하늘이가 먼저 움직인다, `_on_help`), 끝나면 `grants_flag`·`cleared`. 띠·게이지·숫자·실패 화면은 만들지 않는다. **하윤이 직접 시작한다**(#119): `start_prompt`(예: "연 띄우기")가 있으면 원점에 조사 대상(`Start`, `requires_flag` = 물건 플래그, `one_shot`)이 생기고 E로 시작한다 — 하위 부품은 `_ready`에서 `setup_start(trigger_flag)`를 부르고, `starts_on_prompt()`면 저절로 시작하지 않는다. 하늘이 힌트도 그 자리를 가리킨다. 카메라를 잠깐 옆으로 옮기려면 `pan_camera(bias, 초)`(`main.look_bias`, 앞서 보기 위에 더해진다). 하위 부품은 `_begin`·`_tick`·`_on_help`만 쓴다. 검사는 `MiniGame.autoplay = true`(하위 부품이 스스로 잘 해낸다).
- **KiteFly**(들판 2-3): `Node2D` + `scripts/game/kite_fly.gd`, `KiteFly_2-3`(마름모 연과 같은 자리, x 5300). 마름모 연을 줍고 `[E] 연 띄우기`로 시작한다(#119, 줍기만 해서는 시작하지 않는다. 시작한 E 누름은 한 번 떼야 감기로 친다). E를 누르고 있으면 연이 오르고 떼면 내려온다. 하늘의 노을빛 띠(`zone_center` ± `zone_half`, 도움이면 두 배) 안이면 연이 환해진다. 돌풍(`calm` 1.4·`warn`·`gust` 초 — calm은 3초가 길어 #119에서 줄였다)을 `hold_ratio`(60%) 넘게 띠 안에서 버티면 꼬리 리본 하나가 붉게 물든다(셋). 연이 땅까지 오면 한 번 어긋남. 다 버티면 연이 높이 오르고 `grants_flag`(`kite_flown`) → 지도가 보이고, 카메라가 들풀 속 지도 쪽으로 옮겨 갔다(2.2초) 돌아온다(#119). 하윤 자세 `kite`(두 손으로 줄을 잡고 올려다본다). 매 프레임 `player.set_motion()`으로 감을 때 두 손을 번갈아 당기고 몸을 조금 뒤로, 돌풍에는 다리를 벌려 버티고 꽁지머리가 날리며, 고개는 연 높이를 따라간다(#114). 연줄은 하윤 뒤(z -1)에 그려 주먹이 줄을 덮고, 주먹 아래로 남은 줄(`StringTail`)이 조금 늘어진다 — 줄이 손가락 끝에 붙어 보이지 않게.
- **FluteEcho**(숲 4-2 둘째 갈림길, #113): `Node2D` + `scripts/game/flute_echo.gd`, `FluteEcho_4-2`(x 4760). 나무 피리를 가진 하윤이 원점에서 `[E] 피리 불기`로 시작한다(#119). 맞는 입구(`entrance_x` 5600)가 빛나고(`EntranceGlow`) 휘파람 네 음(`melody`, 0 낮음·1 가운데·2 높음)이 입구 자리의 `AudioStreamPlayer2D`로 메아리처럼 들리며, 빛 알갱이가 음 높이(`NOTE_Y`)대로 하윤과 입구 사이에 줄지어 선다. 두 소절이다(#119): 앞 세 음(`first_round_notes`)을 맞추면 흰 테가 한 번 환해지고 네 음 전부가 다시 메아리친다. 하윤 차례에는 ← / E / → 로 분다. 맞으면 하윤의 알갱이가 그 자리에 겹쳐 흰 테, 틀리면 헛바람 소리·알갱이가 흩어지고 한 번 어긋남, 0.5초 뒤 그 소절 메아리가 곧바로 다시(#119). 다 맞으면 입구가 환해지고(빛은 남는다) 하늘이가 그 입구 앞에 가 앉았다가(2.5초) 다시 따라온다. `grants_flag`(`flute_echo_done`). 도움: 메아리가 크고 1.5배 느려지고 알갱이가 흐려지지 않는다. 피리 소리·헛바람은 코드로 만든다(사인파 + 약한 배음 / 거른 잡음, 진짜 소리가 오면 바꾼다). 하윤 자세 `flute`(두 손을 입 앞으로), 피리 그림을 손에 든다. `set_motion`으로 숨 쉬듯 오르내리고, 들을 때는 입구 쪽으로 고개를 기울이고, 음마다 몸이 살짝 밀리고, 틀리면 어깨가 처진다(#114).
- **BankLight**(철교 6-2, #116): `Node2D` + `scripts/game/bank_light.gd`, `BankLight_6-3`(x 3520). 손전등을 가진 하윤이 끊긴 끝에서 `[E] 강둑 비추기`로 시작한다(#119). 하윤 자세 `flashlight`, 손에 든 손전등에서 빛 원뿔(더하기 섞기 Polygon2D)이 나간다. ← 발밑 쪽 · → 먼 쪽(`aim`, 22~88도). 디딤돌 다섯(`stones`)은 가까운 것부터 차례로(사람이 정함, #119), 빛 가운데에 `dwell`(0.7초) 머물면 찾는다(빛을 머금고 남는다). 차례가 아닌 더 먼 돌에 머물면 어긋남이 아니라 "아직" — 그 돌이 한 번 깜빡이고 낮은 종이 울리고 다음 돌이 잠깐 숨 쉰다(신호 `not_yet`). 물그림자(`decoys`)를 오래 비추면 흩어지고 한 번 어긋남(3초 뒤 다시 생긴다). 도움: 빛 1.8배, 하늘이가 짖고, 다음 돌이 빛 밖에서도 숨 쉬고, 물그림자는 더 속이지 않는다. 물그림자는 손에서 본 각도가 이웃 돌과 5도 넘게 떨어지게 둔다(판정은 반폭의 0.6). 다 찾으면 `grants_flag`(`bridge_bank_path`) → `Look_6-3_Slope`가 열린다. 손전등이 있으면 `ask_spot`(`AskSpot_6-3`, 냄새)을 닫고(`used`), 없으면 시작하지 않아 예전 냄새 길로 간다. 안개·돌 자리는 임시 배경의 끊긴 끝·강둑에 맞췄다. 소리(딸깍·종·물소리)는 코드로 만든다.
- **소품 그림은 SVG**(`assets/art/prop/*.svg`, 하윤 그림체: 평면 색 + 그늘 한 톤 + 얇은 따뜻한 갈색 윤곽선). 게임 크기의 2배로 그리고 `.import`의 `svg/scale=0.5`로 들인다(새 SVG를 넣으면 `--import` 뒤 `.import`의 `svg/scale`을 0.5로 고치고 한 번 더 임포트). `find_art`는 진짜 그림(png·jpg·webp) → SVG → placeholder 순으로 찾는다. 빛 알갱이 `fx_light_mote`(물건이 떠오를 때·연 둘레·지도 반짝임). 빛줄기·손전등 빛처럼 번지는 것은 SVG가 아니라 게임에서 그라데이션으로 만든다(Godot SVG는 흐림 효과를 못 그린다).

## 트랙터 (TractorPass, 장면표 2-4)

`Node2D` + `scripts/game/tractor_pass.gd`. 들판 `Tractor_2-4`(땅 위 x 7337, `Gate_2-3` 오른쪽).

- 하윤이 원점 - `trigger_before`(250px)를 지나면 오른쪽 멀리서 트랙터(`prop_tractor`, 하윤 뒤 길가 z -3)가 다가오고 엔진 소리(`sfx_tractor_`, 트랙터에 붙은 `AudioStreamPlayer2D`라 멀어지면 작아진다).
- 하윤은 멈춰(잠금 `tractor`) 몇 걸음 비켜서서 트랙터 쪽을 본다(`player.face`). 가까이 오면 "하윤: 안녕하세요." 농부는 돌아보지 않고 지나간다.
- 대사를 넘기고 트랙터가 하윤을 지나가야 풀린다(신호 `passed` → `finished`). `done_flag`(`tractor_passed`)를 세워 다시 오지 않는다.

## 흔들면 떨어지는 것 (ShakeDrop, 장면표 1-6 사과나무)

`Area2D` + `scripts/game/shake_drop.gd`(조사 대상을 이은 것). 집 마당 `Shake_1-6_Apple`(사과나무 밑동 x 5070, 대문 안쪽).

- "[E] 사과나무 흔들기" → 잎이 몇 장 떨어지고(`sfx_tree_shake_`) 사과 하나(`prop_apple`)가 `drop_from`에서 떨어져 땅에 닿고(`sfx_fruit_drop_`, 신호 `dropped`) 조금 구른다.
- 진행과 상관없다(선택). 조작을 막지 않는다. 한 번만(`one_shot`).

## 물그림자 (WaterReflection, 장면표 5-2)

`Node2D` + `scripts/game/water_reflection.gd` + `shaders/reflection.gdshader`. 강가 `Reflection_5-2`(물가 가운데 땅 위 x 2040, `half_width` 380).

- 하윤이 물가에 들어서면 물에 비친 하윤이 **흐리게**(`clarity` 0.3) 일렁인다. **하늘이는 비치지 않는다**(복선. 7-6 배 위에서는 셋 다 또렷하게 비쳐 짝이 된다).
- 하윤 모습(`Visual`)을 한 번 복사해 물 위 선(`water_y` 816) 아래로 뒤집고 매 프레임 맞춘다. 화면을 거울처럼 비추는 방식은 하늘이까지 비쳐서 쓰지 않는다. 인물 컷아웃이 들어오면 복사·맞추기를 다시 본다.
- 물가에 있는 동안 카메라가 살짝 당겨지고(`camera_zoom` 1.08) 내려간다(`offset.y` 40). 배경이 1080에서 끝나 그냥 내릴 수는 없다.

## 물수제비 (StoneSkip, 장면표 5-4)

`Node2D` + `scripts/game/stone_skip.gd`(`MiniGame`을 이은 것, #115). 강가 `Skip_5-4`(동그라미 4 조사 대상 `Look_5-4_Shallows`와 같은 자리, x 6390). 돌 주머니는 그 앞 `Keepsake_5-4_Pouch`(x 6050).

- 같은 동그라미(`circle` 4)의 조사 대상이 지도 → 기억 장면(할아버지의 돌 다섯 번) **다음에** `play()`를 기다린다.
- **돌 주머니가 없으면**(`pouch_flag` = `item_stone_pouch`): 예전 연출 — 하윤이 쪼그려 납작한 돌을 줍고(잠금 `stone_skip`, `StoneSkip.DEMO_LOCK`) 옆으로 낮게 던진다(`player.play_throw()`, 키 `HayunRig.THROW_KEYS`). `skips`(2)번 튀고 가라앉는다. 끝나면 글 "하윤: …다섯 번은 어렵다.".
- **있으면 선택 미니게임**(잠금 `minigame`): 물 위에 할아버지 물결 다섯 자리(`Ghost0~4`, 희미한 타원)가 남는다. E를 누르고 있으면 하윤이 몸을 낮춰 팔을 젖히고(`set_motion`), 손에서 나간 점선 궤적(`Aim`, 점 무늬를 되풀이한 Line2D)이 각도 -2~46도로 오르내린다(20도 ±6이면 금빛). 떼면 던진다: `skips_for(각도)` — 20도 ±4 → 다섯, ±8 → 넷, ±13 → 셋, ±19 → 둘, ±26 → 하나, 그 밖은 바로 가라앉는다. 튄 자리마다 물결 자리가 채워진다(물은 `hop_lengths` 다섯 칸). 발밑 돌무더기(`stones` 다섯)가 남은 돌이고, 다 쓰면 하늘이가 물가에 갔다 와서 다시 채운다. 튈 때 카메라가 돌을 살짝 따라가고(`pan_camera`), 튈수록 물결이 커지고 셋째부터 물방울이 튀며 소리가 높아진다(#119). 셋 미만이면 한 번 어긋남 → 세 번이면 각도가 0.55배로 느려진다. ← →로 그만둔다. 다섯 번을 튀기면 `five_flag`(`skip_five`), 하늘이가 짖고(`DogRig.bark`) 물결 자리가 금빛으로 환해지며 기억 장면이 한 번 더 나오고 끝난다 — 그때는 "…다섯 번은 어렵다."를 띄우지 않는다(`Interactable`이 `skip.best >= 5`를 본다).
- 물수제비는 물과 약 20도로 낮게 닿아야 잘 튄다(Clanet 외, Nature 2004). 돌은 손 자리(`player.hand_point()`)에서 낮고 평평하게(높이 18px) 날아간다.

## 빛 알갱이 (LightMotes, 장면표 4-1·4-2)

`Node2D` + `scripts/game/light_motes.gd`. 숲 입구 `Motes_4-1`(땅 위 x 891).

- 하윤이 원점을 지나면 금빛 알갱이가 땅에서 한꺼번에 떠오르고, 그 뒤로 화면 둘레에서 생겼다 사그라든다(`count` 70). z 5(하윤 앞, 앞 층 뒤).
- 하윤이 `gather_from`~`gather_to`(3000~5900, 4-2 빛 갈림길)에 있으면 새 알갱이는 **하늘이 발밑에서만** 생기고, 먼 알갱이는 빨리 사그라든다(복선).

## 벤치 (BenchSit)

`Area2D` + `scripts/game/bench_sit.gd`(조사 대상을 이은 것). 이름 `Sit_<장면>`, 벤치 가운데 땅 위.

- `auto_sit = true`(3-3): 하윤이 들어오면 저절로 `sit_seconds`(6초, 15초에서 #118로 줄임) 앉는다. 앉고 1.2초(`WRIST_AT`) 뒤 손목을 만진다(복선). 그동안 장소 층이 `tint`로 물들고 환경음이 `ambience_duck_db`만큼 줄고, 끝 무렵 `end_sound`. 다 앉으면 `grants_flag`(`station_sat`)를 세우고 일어난다. 안내 글 없음.
- `auto_sit = false`(2-5): "[E] 앉기" → 방향키나 E로 일어난다. 조작 잠금 이유 `sit`.
- 하늘이 만남은 `appears_on_flag`(`station_sat`)가 서야 하늘이가 나타난다. 그래서 3-3 벤치는 만남 자리보다 왼쪽, 알아채는 거리(360px) 밖에 둔다.

## 빈터의 빛 (ClearingLight, 장면표 4-3)

`Node2D` + `scripts/game/clearing_light.gd`. 숲 `Light_4-3`과 바닥 앉기 `Sit_4-3`(BenchSit, `pose` `sit_floor`, `requires_flag` `map_circle_3`, 둘 다 x 6120).

- 동그라미 3 뒤에 "[E] 앉기" → 하윤이 바닥에 앉으면(`sat_down`) 위에서 빛기둥이 짙어지고 금빛 알갱이가 쏟아지며 장소 층이 `place_tint`로 밝아진다(신호 `poured`).
- 하늘이는 그 자리에 멈춰(`dog.script_move_to`) `look_dir` 쪽을 보고 꼬리를 신나게 흔든다(`dog.wag(true)` → `DogRig.set_excited`).
- 일어나면(`stood_up`) 천천히 돌아오고 하늘이를 놓아준다(`faded`). 몇 번이든 앉을 수 있다. 대사 없음.

## 오프닝과 영정사진 (장면표 0-1, 1-2, 7-8)

- **0-1 오프닝** `scripts/game/opening.gd`(`OpeningScene`, 집 `Opening_0-1`): 손그림 컷신 0(`cut_accident`, 사고 뒤 비 오는 밤 길가에 할아버지의 모자와 카메라. 사람·하윤 물건은 그리지 않는다)과 빗소리(`sfx_rain_`) → 어둠이 걷히고 하윤이 일어난다(잠금 `opening`, 끝나면 `opening_seen`).
  타이틀 "처음부터"가 `GameState.opening_pending`을 켰을 때만 나온다. 이어하기·검사(main을 바로 띄움)에는 없다.
- **1-2 영정사진** `scripts/game/funeral_portraits.gd`(`FuneralPortraits`, 집 `Portraits_1-2`): 할아버지(`prop_portrait_grandpa`)는 또렷하고 옆 하윤(`prop_portrait_hayun`)은 `shaders/blur.gdshader`로 누구인지 안 보이게 흐리다. 조사할 수 없는 배경.
  하윤 사진은 또렷하게 그린 것을 받는다. 흐리게는 게임이 한다.
- **7-8** `BoatRide._portraits_card`: 제목 뒤 하얀 화면에 같은 두 장이 비치고 하윤 사진이 `portrait_reveal_seconds`(4초)에 걸쳐 또렷해진다(`portraits_revealed`) → 타이틀로.
- 캔버스 셰이더의 fragment `COLOR`는 이미 그림 색을 곱한 값이다. 그림을 직접 읽어 섞는 셰이더(흐림 등)는 꼭짓점 색을 `vertex()`에서 따로 받아 곱한다(`blur.gdshader`).

## 엔딩 (나루터 7-3 ~ 7-8)

- **할아버지** `scenes/characters/grandpa.tscn`(`Grandpa`): B가 나루터 씬에 놓는다(`Grandpa_7-3`, 배 옆 땅 위). `appears_on_flag`(`map_circle_5`)가 서면 천천히 나타난다. `raise_camera()`/`lower_camera()`. 걷지 않는다(기획서).
- **엔딩 연출** `scripts/game/ending.gd`(`EndingDirector`): 할아버지 옆에 놓는다(`Ending_7-3`). 다섯째 동그라미 뒤 하윤이 `trigger_distance`(380px) 안으로 오면 시작하고 끝까지 조작을 막는다(잠금 이유 `ending`).
  하윤이 달려가다 멈춤(`player.auto_move_to`) → 하늘이가 먼저 할아버지에게(`dog.script_move_to`) → "할아버지: 왔니." → 컷신 1(팔찌) → 하늘이가 발치에 앉고 셔터(`ending_photo`) → 강 위 구간으로(`crossing_scene`).
- **7-1 안개** `scripts/game/mist_reveal.gd`(`MistReveal`, 나루터 `Mist_7-1`): 들어서면 하얀 안개가 걷히고 휘파람 선율이 작게 시작된다.
- **7-6 강 위 구간** `scenes/places/crossing.tscn`(place_id `crossing`, 지도에는 없음) + `scripts/game/boat_ride.gd`(`BoatRide_7-6`): 셋이 탄 배가 `ride_seconds`(70초) 동안 저절로 흘러간다(조작 없음, 잠금 `ending`). 강 건너 안개에 지나온 장소 다섯이 차례로 비친다(각 장소의 `bg_<장소>_mid` 그림을 `shaders/ghost.gdshader`로 바래게 — 진짜 그림이 오면 그것이 비친다). 물에 비친 셋은 또렷하다(모습을 뒤집어 복사). 하윤이 물을 한 번 만진다. 휘파람 선율을 처음부터 끝까지(`restart`) → 컷신 2(`cut_boat`, 하얗게 번짐) → 제목 → `ending_seen` → 타이틀로(`return_to_title`, 검사는 끈다).
- **음악**: `main.play_music(이름, dB, 페이드, restart)` / `fade_music` / `stop_music`. 장소를 옮겨도 끊기지 않는다(`Music` 버스).
- **컷신 재생** `scripts/ui/cutscene_player.gd`(`CutscenePlayer`, B): 한 장짜리 그림에 천천히 확대·이동, 글자는 글꼴로 얹는다(팔찌 "이하윤 / 9세"). 그림은 이름(`cut_bracelet`)으로 `assets/art` 아래에서 찾고 진짜 그림 → SVG 소품 → placeholder 순이다. 대사 상자보다 아래 층(5)이라 컷신 위로 대사가 보인다.
- 나루터 `Gate_7-3`(`map_circle_5`): 다섯째 동그라미 전에는 할아버지 쪽으로 못 간다.

## 대사 상자 (DialogueBox)

- `scenes/ui/dialogue_box.tscn`, `main.tscn`의 `Overlay` 아래. 그룹 `dialogue_box`로 찾는다.
- `play(lines)` → 한 줄씩 글자가 찍히고(초당 30자) E로 넘긴다 → 다 넘기면 `finished`.
- 글꼴은 기본 테마 글꼴(`project.godot` `gui/theme/custom_font` = `ui_subset.ttf`, 고운돋움 — 메뉴와 같은 글꼴, #100). 제목·장소 이름 카드는 `title_subset.ttf`(고운바탕 굵게). 본고딕 서브셋은 지도 손글씨에 없는 글자를 대신 그리는 데만 쓴다.
- 열려 있는 동안 하윤 조작을 막는다.

## 장소 이름 카드·걷기 안내

- `scenes/main.tscn`의 `Overlay/PlaceCard`(`scripts/ui/place_card.gd`, `PlaceCard`): 장소에 들어서면(`main._swap_place`) 그 장소의 `display_name`이 화면 가운데 위에 제목 글꼴(고운바탕 굵게, #100)로 떴다가 사라진다(1.0초 들어오고 2.4초 머물고 1.4초 사라짐). **하윤이 조작할 수 있게 된 뒤에** 뜬다(장소 전환 페이드·0-1 오프닝 위에 겹치지 않게). `display_name`이 비면(강 위 구간) 안 뜬다. 늘 떠 있던 장소 이름 글과 "A D / ← → 이동" 개발용 글은 없앴다(#87).
- `Overlay/WalkHint`: 집에서 처음 조작이 풀리면 아래에 "A D / ← →  걷기". 하윤이 240px 걸으면 사라지고 `walked_once` 플래그를 세운다(이어하기 뒤에도 다시 안 뜬다).
- 엔딩·배 위에서는 `PlaceCard`·`WalkHint`·`MapHint`·`Vignette`를 감춘다(`ending.gd`, `boat_ride.gd`).

## 화면 마무리 (카메라·알갱이·비네트, #90)

- **카메라 앞서 보기**(`main._update_look`): 하윤이 걸으면 카메라 `offset.x`가 걷는 쪽으로 `LOOK_AHEAD`(150px)까지 따라가고, 멈추거나 조작이 막히면 천천히 가운데로 돌아온다. 장소를 옮기면 0부터. `offset.y`·`zoom`은 물그림자(5-2)가 쓴다.
- **떠다니는 알갱이** `World/Player/Camera/Dust`(`scripts/game/ambient_dust.gd`, `AmbientDust`): 장소마다 `SETTINGS`(집 햇빛 속 먼지, 들판 날리는 씨앗). 없는 장소는 끈다(숲은 빛 알갱이가 따로 있다). z 4(하윤 앞, 앞 층 뒤).
- **비네트** `Overlay/Vignette`(`shaders/vignette.gdshader`): 화면 가장자리를 살짝 어둡게. 대사 상자·지도보다 아래.
- 앞 층 기둥(집·간이역·숲·철교)은 가늘고 흐리게 그린다(`placeholder_art.py`의 `soft_rect` + `Layer.haze`). 진짜 그림도 앞 층은 하윤을 가리지 않게 가늘게, 초점이 나간 듯 그리는 것이 좋다.

## 지도 (MapScreen)

- `scenes/ui/map_screen.tscn` + `scripts/ui/map_screen.gd`(펼치기·접기·체크), `scripts/ui/map_canvas.gd`(그리기), `scripts/game/map_data.gd`(자리·메모).
- `has_map` 플래그가 서야 M이 먹는다 → 1-5의 서랍 조사 대상에 `grants_flag = has_map`을 준다.
- `has_map`이 서면 화면 왼쪽 위에 "[M] 지도"가 뜨고, 처음 펼치면(`map_opened` 플래그) 사라진다(장면표 1-5 "M 안내").
- **동그라미 체크는 조사 대상의 `map_circle`(1~5)** 로 한다. E → 지도가 펼쳐지고 그 동그라미에 체크 → 하윤이 접으면 그 조사 대상의 `lines`가 나온다. 플래그 `map_circle_1`~`map_circle_5`. 장면 2-2, 3-1, 4-3, 5-4, 7-2.
- **하윤 글씨 동그라미 클로즈업**(7-2): `MapData.CIRCLES`의 `child`가 참인 동그라미(다섯째)는 체크한 뒤 동그라미와 메모 사이로 `CLOSEUP_ZOOM`(2배)까지 천천히 다가간다(`MapScreen.closeup`). 가운데는 종이 안쪽으로 당겨 확대해도 종이가 화면을 다 덮는다. 접으면 물러났다가 접힌다.
- 지나온 길은 지금 장소의 `place_id`와 그 안에서의 위치로 그린다. 새 장소를 만들면 `MapData.PLACES`에도 넣어야 지도에 나온다.
- 메모 문구는 `map_data.gd` 한 곳에 있다. 고치면 `docs/design.md` "지도의 다섯 동그라미" 표도 같이 고친다(글꼴 도구가 둘 다에서 글자를 모은다).
- **지도 그림**: `MapData.PAPER_ART`(`assets/art/map/`)가 있으면 그 그림을 `PAPER_RECT`(1740×980)에 깔고, 코드는 접힌 자국·강·철교·작은 기호·배를 그리지 않는다. 동그라미·메모·체크·지나온 길·장소 이름은 코드가 그린다(그림 위에서는 종이색 테두리). 길과 가지 않는 길은 그림에 아직 없어서 코드가 그린다 — 그림에 들어오면 `_draw_route`·`_draw_side_roads`도 끈다. 좌표는 그림에 맞춰 `map_data.gd`만 고친다.
- **동그라미 모양**: 손으로 휙 그린 타원 — 옆으로 조금 길고 비스듬하며(동그라미마다 기울기·찌그러짐이 다르다) 한 바퀴 넘게 돌아 두 끝이 엇갈리고, 시작·끝은 가늘고 옅게 빠진다(`_draw_circle_mark`).
- **색연필 질감**: 코드가 긋는 선(길·동그라미·체크·지나온 길, 굵기 `LINE_W` 6 · `TRAIL_W` 8 · `CHECK_W` 9)에는 `shaders/pencil.gdshader`가 걸린다(종이 결에 걸려 군데군데 비고 한 방향으로 긁힌 결, 결은 지도 좌표에 붙는다). 그래서 지도 그림은 `_draw`가 아니라 뒤에 깐 자식 `Paper`(TextureRect, `show_behind_parent`)가 그리고, 글(Label 자식)에는 질감이 안 걸린다.
- **지도 글씨**: 맨 위 메모·장소 이름·메모 1~4는 할아버지 글씨(`grandpa_hand_subset.ttf`, Nanum Pen Script), 다섯째 메모만 하윤 글씨(`hayun_hand_subset.ttf`, Gamja Flower)다(반전 복선). 둘 다 지도 문구 글자만 든 서브셋이라, 지도 문구를 고치면 `python3 tools/font_subset.py`로 세 글꼴을 다시 만든다(CI가 `--check`로 본다). 없는 글자는 본문 글꼴로 그린다(`map_canvas.gd`의 fallback).
- **기억 장면**(동그라미 1~4, `scripts/game/memory_scene.gd` `MemoryScene`): B가 그 동그라미 조사 대상 오른쪽에 놓는다(`Memory_2-2`, 원점은 그림 아래 가운데, y 890이면 그림의 땅 선이 땅에 맞는다). `circle`이 같은 조사 대상이 지도를 접은 뒤 `play()`를 기다리고 나서 글을 띄운다. 단색 선 스케치(`art`, 예: `mem_wind`)를 `shaders/memory.gdshader`로 빛처럼 희미하게 겹치고, 그동안 휘파람 한 소절(`phrase` = `mus_phrase_N`, 한 번만)이 나고 환경음이 줄고 하윤 조작이 멈춘다(잠금 이유 `memory`). 대사 없음.
- 지금 그림(`map_paper.jpg`, 1080×608 JPEG)이 일러스트 담당의 **최종본**이다. 좌표는 이 그림에 맞춰져 있다.

## 저장·타이틀

- 시작 씬은 타이틀(`scenes/ui/title_screen.tscn`): "이어하기"(저장이 없으면 꺼짐) / "처음부터".
- **장소에 들어갈 때 자동 저장**(`main._swap_place` → `GameState.save_game`). 강 위 구간(`crossing`)은 저장하지 않고, 엔딩을 끝까지 보면 저장을 지운다(#107 — 엔딩 뒤 이어하기가 배 장면부터 다시 나왔다). 저장하는 것은 그 장소 씬과 그 순간의 플래그뿐이다. 이어하기는 그 장소 처음부터 한다.
  그래서 **장소 안의 진행은 플래그로 남겨야** 이어하기 뒤에도 유지된다(조사 대상 `grants_flag`, 부탁 자리 `grants_flag`, 지도 `map_circle_N`, `dog_joined`).
- 저장 파일 `user://save.cfg`. 헤드리스(검사·CI)에서는 자동 저장이 꺼져 있다(`GameState.autosave`). 저장을 시험하는 검사는 `save_path`를 바꾸고 켠다.

## 일시정지 메뉴

- `scenes/ui/pause_menu.tscn`, Esc(`pause`). `main.tscn`의 `MenuLayer`(CanvasLayer 50)에 둔다 — 모든 화면(장소 전환 검은 막 `Overlay/Fade`, 엔딩 제목·영정 카드 30·31)보다 위(#107, 예전에는 `Overlay` 안에서 `Fade` 아래라 검은 화면에서 Esc를 누르면 메뉴가 안 보였다). 열면 `get_tree().paused = true`로 게임 전체가 멈추고 메뉴만 돈다(`PROCESS_MODE_ALWAYS`).
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
- 쓰는 이유: `place_change`(장소 전환), `dog_task`(하늘이 가져와·냄새), `dialogue`(대사 상자), `meeting`(하늘이 만남), `map`(지도), `album`(앨범 1-3), `cutscene`(조사 대상의 손그림 컷신 1-5), `map_chase`(날아간 지도 2-3), `tractor`(트랙터 2-4), `memory`(기억 장면), `sit`(벤치), `ending`(엔딩), `opening`(오프닝 0-1), `moment`(작은 순간), `stone_skip`(물수제비 5-4), `minigame`(미니게임, #111), `pickup`(물건 줍는 동작, #114). 새로 막을 일이 생기면 새 이유 이름을 쓴다 — 남의 이유를 풀지 않는다.

## 인물 컷아웃 (Cutout)

- 그림 담당이 클립 스튜디오에서 레이어로 나눠 그린 PSD → `tools/psd_split.py` → `assets/art/char/<인물>/char_<인물>_<부위>.png` + `char_<인물>.json`(레이어 규칙은 도구 맨 위 설명).
- `scripts/game/cutout.gd`(`Cutout`, Node2D): JSON대로 Sprite2D 조각을 붙인다. 원점 = PSD 캔버스 아래 가운데 = 발밑, `art_scale`로 게임 크기.
  - 눈·입·눈썹(`eye_`/`mouth_`/`brow_` + 상태)은 한 번에 하나만 보인다: `set_state("eye", "closed")`. 처음은 open·neutral.
  - 자세(`poses`, 예: `stand`, `sit`)가 있으면 `set_pose("sit")`로 그 자세 조각만.
  - `blink`면 2.5~6초마다 eye_half → eye_closed → eye_half → 원래 눈.
- **하윤**(#94, `HayunRig` — "하윤" 절)과 **하늘이**(#101, `DogRig` — "하늘이" 절)는 붙였다. 할아버지는 그림이 오면 같은 방식으로 `Visual` 아래에 넣고 회색 네모를 끈다. 그림자·물그림자는 `Visual`을 복사하므로 같이 따라온다.
- 관절(Skeleton2D)·움직임(AnimationPlayer)은 그림 담당과 관절 자리를 정한 뒤 더한다.

## 하늘이

- `scenes/characters/dog.tscn` + `scripts/dog/dog.gd`. 하윤처럼 `main.tscn`이 들고 있다.
- **그림·움직임**(#101): 그림 담당의 원본 PSB(한글 레이어 12장)를 `python3 tools/psd_split.py 하늘이.psb --char dog --names tools/psd_names/haneul.json --mirror --height 346`로 잘라 `assets/art/char/dog/`에 둔다(왼쪽을 보고 그려서 뒤집고, 2배 크기, 귀 끝 약 160px·등 약 120px). 원본 PSB는 저장소에 넣지 않는다(팀 드라이브). `dog.gd`가 그림이 있으면 `Visual/Rig`(`scripts/dog/dog_rig.gd`, `DogRig`)를 만들고 회색 네모(`Stand`/`Sit`)를 숨긴다. 하윤과 같은 방식(조각은 한 층, 관절은 계산, 먼 쪽 다리는 복사해 그늘 색, 발이 땅에 닿게 몸 높이). 걷기는 속보(가까운 앞다리 = 먼 뒷다리, `CYCLE` 170px), 꼬리 세 마디는 늘 흔들고 걸을 때 더 크게, 앉기(`SIT`·만남·연출 정지)는 몸 뒤쪽(`rear`)을 앞 어깨 축으로 내려 엉덩이를 땅에 대고, 허벅지를 앞으로 눕혀 뒷발을 앞다리 뒤 땅에 놓고, 꼬리를 땅에 내려놓는다. 심부름(#103): 목(`neck`, 가슴 앞 아래 축 — 머리·목줄을 통째로 내린다)으로 물어 오기 `fetch`·냄새 `sniff`(킁킁 잘게)·냄새 따라 걷기 `sniff_walk`, 버티기 `hold`(다리를 앞뒤로 벌림), 짖기 `bark()`(고개를 젖힘). `dog.gd`의 `_rig_pose()`가 상태와 부탁 종류로 고른다. 자세 옮기기는 하윤처럼 관절마다 용수철(`DogRig.POSE_OMEGA`), 가만히 있으면 목이 숨쉬듯 오르내리고 3~7초마다 귀를 움찔한다(#114). 그림은 지금 모습(밝은 강아지 느낌) 그대로 간다(사람이 정함).
- **일상 교감**(#120): 부탁 자리 밖에서 F를 누르면 쓰다듬기(`dog.pet()`, `can_pet()`) — 하늘이가 하윤 앞 `PET_GAP`(175px)에 와서 마주 보고 앉아 올려다보며 꼬리를 흔들고, 하윤이 쪼그려 앉아 `PET_SECONDS`(2.6초) 동안 머리를 쓰다듬는다. 하윤을 잠그지 않고 걷기 시작하면 곧바로 끝난다. 쓰다듬는 중에도 부탁 자리 F가 먼저다. 하윤이 `LOOK_UP_AFTER`(3.5초) 넘게 가만히 서 있으면 앉아서 올려다본다(`DogRig.set_look_up`). 미니게임 중에는 `MiniGame.dog_react()` → `dog.perk()`(`DogRig.perk`: 귀를 쫑긋 세우고 고개를 든다)로 반응한다 — 메아리·피리 음, 연 돌풍 버티기(꼬리), 물수제비 튈 때마다, 손전등 돌이 켜질 때(마지막은 꼬리).
- **돌아서기**(#120 모션 손질): 하윤(`Player.TURN_SECONDS` 0.14)·하늘이(`Dog.TURN_SECONDS` 0.16)는 방향을 바꿀 때 한 번에 뒤집지 않고 그 시간에 걸쳐 돈다(`Visual.scale.x`). 연출용 `face()`·`look()`은 바로 돈다.
- 합류 전에는 보이지 않는다. 합류는 만남 부품(아래)이 시킨다. 코드로는 `dog.join(player)`이고 `dog_joined` 플래그를 세운다.

### 하늘이 만남 (DogMeeting, 장면표 3-4)

- **B가 간이역 씬의 3-4 자리에 놓는다.** `Node2D`에 `scripts/dog/dog_meeting.gd`를 붙이고 땅 위(y = 810)에 둔다. 이름은 `DogMeeting_3-4`.
- 하늘이가 그 자리에 앉아 있다 → 하윤이 다가가면 두 번 물러난다(`retreats`, `retreat_distance`) → 세 번째에 `[E] 쪼그려 앉기` → 하윤이 쪼그려 앉고 하늘이가 다가옴 → 이름표 글 "하늘", "하윤: 하늘이…?" → 합류.
- 물러날 자리가 장소 안에 있어야 한다: 놓는 자리 + `retreats × retreat_distance`(기본 600px)가 장소 끝 지점보다 왼쪽이어야 한다.
- 3-5의 첫 부탁 자리(가져와)는 이 자리보다 오른쪽에 둔다. 합류 전에는 F가 먹지 않는다.
- 이미 합류했으면 아무 일도 하지 않는다. 만남 중에 장소를 떠나면 하늘이는 다시 숨는다.
- 부탁할 수 있으면 하늘이 머리 위에 발바닥 그림과 `[F] 가져와`/`냄새 맡아 줘`/`기다려`가 떠서 살랑인다(`scripts/dog/paw_mark.gd`, 문구 `Dog.ASK_HINTS`). 예전에는 "F" 글자 하나라 무슨 키인지 몰랐다(#109).
- 하윤 뒤 120~180px(`FOLLOW_GAP` 150), 멈추면 2초 뒤 앉는다. 장소를 옮기면 하윤 뒤에 다시 선다(하던 부탁은 취소).
- **힌트**: 하윤이 조작할 수 있는 채로 8초 가만히 있으면, 하늘이가 다음 목표 쪽으로 최대 160px 앞서 가서 1.5초 바라보다 돌아온다(같은 정지 동안 한 번).
  다음 목표 = **지나쳐 온(하윤보다 왼쪽) 안 쓴 부탁 자리가 있으면 그것**(가장 가까운 것, #107 — 간이역 3-5에서 F를 놓치면 되돌아가라는 신호가 없었다), 없으면 하윤보다 오른쪽의, 아직 안 쓴 부탁 자리 · `map_circle` 조사 대상 · `one_shot` 조사 대상 중 가장 가까운 것. 없으면 장소 끝 지점.
  그래서 **진행에 필요한 조사 대상은 `one_shot`으로** 두면 힌트가 가리킨다(되풀이 조사용 분위기 대상은 안 가리킨다).
- 하윤이 막혀 있으면(대사·지도·벤치·연출, `controls_enabled`가 거짓) F가 먹지 않는다(#107 — 돌아와서 띄우는 대사가 읽던 대사를 덮어썼다).

## 하윤

- `scenes/characters/player.tscn` + `scripts/player/player.gd`. 원점은 발밑, **키는 약 300px**(모자까지 약 320, 9살 약 130cm, 1cm ≈ 2.3px — #92에서 세 인물 모두 1.5배). 할아버지는 약 400px(모자까지 440), 하늘이는 등 약 110px·귀 끝 약 160px.
- **그림·움직임**(#94): 그림 담당의 원본 PSB(한글 레이어 17장)를 `python3 tools/psd_split.py 캐릭터.psb --char hayun --names tools/psd_names/hayun.json --mirror --height 645`로 잘라 `assets/art/char/hayun/`에 둔다(왼쪽을 보고 그려서 뒤집고, 게임 크기의 2배로). 원본 PSB는 저장소에 넣지 않는다(15MB, 팀 드라이브에 있다).
  - `Visual/Rig`(`scripts/player/hayun_rig.gd`, `HayunRig`)가 `Cutout`을 만들고 관절을 돌린다. 관절 자리 `JOINTS`(캔버스 px)와 조각→관절 `PART_JOINT`. 조각은 한 층에 그대로 두고 관절은 계산으로 잇는다 — 그림자·물그림자가 `Visual`을 자식 순서대로 복사해 맞추기 때문이다(그래서 `Visual`을 복사할 때는 `duplicate(0)`, 스크립트까지 복사하면 조각을 한 번 더 붙인다).
  - 먼 쪽 팔다리는 가까운 쪽을 복사해 그늘 색(`FAR_TINT`)으로 맨 뒤에 깐다(원본 레이어 순서대로 — 정강이가 허벅지 위에 오면 무릎이 인형 관절처럼 보인다)(그림 담당과 정함: 한 세트만 그린다). 반창고가 허벅지에 같이 그려져 있어 먼 쪽 다리에도 보인다.
  - 걷기는 걸은 거리로 굴린다(`CYCLE` 220px = 두 걸음): 허벅지·무릎·발목(발은 땅과 나란히), 팔을 다리와 반대로, 뒤(14도)보다 앞(30도)으로 크게, 어깨는 원본 자리 그대로(`ARM_SHIFT` 0 — 앞으로 옮겼더니 팔이 앞에 달린 것 같았다). 몸통 그림의 겨드랑이 진한 주황 그늘은 팔을 흔들면 드러나 몸통 옆면 색으로 바꿔 둔다(`ARMPIT_SHADE` → `BODY_SIDE`)(팔꿈치는 팔이 앞으로 올 때만 18도까지 굽힌다. 아래팔 소매의 둥근 윗단은 `FOREARM_CROP`줄 지우고 `FOREARM_FADE`줄에 걸쳐 서서히 나타나게 해 굽혀도 윗소매 밖으로 안 튀어나온다(딱 자르면 윤곽선에 턱이 생긴다)). 바지는 먼 쪽에도 하나 깔아 먼 다리를 따라 흔든다(뒤쪽 바짓단이 보이게). 바지는 모양 그대로 엉덩이 관절 높이, 허벅지 앞쪽의 축(208,328)을 중심으로 돌린다(앞 0.5·뒤 0.6. 기울이기로 밀면 늘어나 보였다). 앉는 자세(앉기·쪼그리기·바닥 앉기)에서는 바지가 허벅지를 따라 거의 눕고(가까운 쪽·먼 쪽 모두 허벅지 각도 가까이) 허리 쪽 윗단이 뒤로 돌아 엉덩이가 된다 — 예전에는 바지가 몸통 아래 수직으로 매달려 앉아도 치마처럼 보였다(사람 의견). 축이 윗옷 밑단 높이(300)였을 때는 눕히면 무릎 위에 상자를 얹은 것처럼 보였고, 축이 엉덩이 뒤쪽(190)이면 허리 윗단이 등 뒤로 삐져나왔다, 무릎은 발을 든 쪽만 가운데에서 뾰족하게(22도) 굽히고, 발은 다리를 절반만 따라 돈다(`ANKLE_FLATTEN` 0.5 — 늘 땅과 나란히 두면 종아리가 흐물거린다, #96). 몸 높이는 낮은 발바닥이 땅에 닿게 계산한다(고정 오르내림이면 다리를 벌릴 때 두 발이 뜬다), 꽁지머리는 뒤로 날리며 가만히 있어도 살랑인다. 눈은 가끔 눌러서 깜빡인다(감은 눈 그림이 없어서). **손목 만지기**(#110, 장면표 대기 동작·팔찌 복선): 5초 넘게 가만히 서 있거나 벤치에 앉아 있으면 화면 쪽 손목을 몸 앞에 들고 먼 손으로 문지르며 내려다본다(약 2.8초, 그 뒤 9~15초마다). `HayunRig.WRIST_KEYS`/`WRIST_SIT_KEYS`, 시작은 `player._update_idle`(잠금은 `sit`만 허용), 신호 `wrist_touched`. 걷기 시작하면 서둘러 내린다. 멈추면 0.25초에 걸쳐 선다.
  - **자세**(#98): `player.set_pose(&"stand"|&"crouch"|&"sit"|&"sit_floor")`. 컷아웃은 `HayunRig.POSES`의 관절 각도로 옮겨 가는데, 관절마다 용수철(`POSE_OMEGA`, `POSE_DAMPING` 0.72, #114)이라 몸통·다리가 먼저 가고 팔·머리·꽁지머리가 조금 늦게 따라와 살짝 넘쳤다 돌아온다(모든 관절이 같이 도착하면 꼭두각시처럼 보였다). 장면이 매 프레임 얹는 움직임은 `player.set_motion({관절: 도})`(자세 위에 더해지고 같은 용수철로 따라간다). 가만히 있으면 숨쉬기(`BREATH_*`), 걸으면 몸이 `WALK_LEAN`(3.5도) 앞으로 기운다. 몸 높이는 발바닥·바지 아랫단 중 낮은 것이 땅에 닿게 맞춘다. 컷아웃이 없으면 예전처럼 `Visual`을 세로로 누른다. 쪼그리기 = 하늘이 만남·돌 줍기·배 위에서 물 만지기, 앉기 = 벤치, 바닥 앉기 = 오프닝 거실 바닥·배 위, `kite` = 연줄 잡기(2-3), `flute` = 피리 불기(4-2). `player.crouching`은 서 있지 않으면 참. 상체는 엉덩이를 축으로 숙인다(`torso` 관절 — 몸통·머리·팔·바지가 같이 기울고 다리는 그대로. 쪼그리기 22도, 던질 때 8~26도).
  - **팔찌가 아직 없다**(그림 담당에게 `팔찌` 레이어를 부탁했다, 이름표에는 `bracelet`으로 미리 넣어 둠). 할아버지는 아직 회색 네모(1.5배). 인물 그림 크기 기준은 `assets/art/README.md` "크기".
- **그림자** `scripts/player/player_shadow.gd`(`PlayerShadow`, `Player/Shadow`, CanvasGroup): 하윤 모습을 복사해 땅에 눕힌다. 장소마다 진하기·길이·방향은 `SETTINGS`(place_id별). 장소를 지날수록 옅어지고(복선) 숲부터는 거의 없다. 들판에서는 임시 배경의 전봇대 그림자(진하기 약 0.43)보다 옅게(0.26).
- 걷는 속도 300px/초 = 화면 하나를 약 6.4초(#29에서 200 → 250, 2026-11-21 250 → 300). 장소 폭은 200 기준으로 잡았다. 하늘이 속도(따라오기·심부름·만남·힌트)는 200 기준의 1.5배로 같이 올렸다. 속도를 또 바꾸면 장면표 시간도 다시 본다.

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
