# 소리 넣는 법

소리는 이 폴더에 **이름 규칙대로 넣고** 소리 가져오기 도구를 돌리면 반복 설정이 맞춰지고, 장소 환경음은 장소에 자동으로 들어간다. 하위 폴더는 마음대로 만들어도 된다.

## 이름

| 앞머리 | 무엇 | 반복 | 어디서 트나 |
| --- | --- | --- | --- |
| `amb_<장소>` | 장소 환경음(바람, 강물, 풀벌레) | 반복 | 장소 씬 `Sound/Ambience`에 **자동으로** 들어간다 |
| `pos_<장소>_<이름>` | 장소 안 한 자리에서 나는 소리(라디오, 숲 끝 물소리) | 반복 | 장소 씬 `Sound/` 아래 `AudioStreamPlayer2D`로 **손으로** 놓는다. 가까이 가면 커진다 |
| `mus_<이름>` | 음악(휘파람 주제 선율) | 반복 | A가 튼다 |
| `mus_phrase_<N>` | 기억 장면 N(동그라미 1~4)의 휘파람 한 소절 | 한 번 | 기억 장면(`MemoryScene.phrase`)이 튼다 |
| `step_<바닥>_NN` | 하윤 발소리. 바닥: `wood` `dirt` `grass` `concrete` `soil` `pebble` `metal` `deck` | 한 번 | A가 튼다(하윤 스크립트) |
| `sfx_<이름>_NN` | 효과음(하늘이 발톱 `sfx_dog_claw`, 서랍, 지도…). 2-3 날아간 지도: `sfx_wind_gust`(센 바람, 지도가 날아갈 때마다), `sfx_paper`(지도 줍기). 2-4 `sfx_tractor`(경운기 엔진, 지나가는 동안 약 16초 한 번). 1-6 `sfx_tree_shake`(감나무 흔들기), `sfx_persimmon_drop`(감이 땅에 툭) | 한 번 | A가 튼다 |

모두 **소문자**, `.ogg`(권장) 또는 `.wav`. `<장소>`는 `house field station forest riverside bridge ferry`.

## 크기·소리

- 환경음은 20~60초, **처음과 끝이 이어지게**(반복할 때 딸깍 소리가 나지 않게) 자른다.
- 모노로 충분하다. 44.1kHz 또는 32kHz.
- 기획서: **현실 소리가 점점 줄어든다.** 집(생활 소리, 처마 풍경) → 들판(바람, 억새) → 간이역(노을 정적) → 숲(풀벌레) → 강가(강물) → 철교(바람) → 나루터(물소리와 주제 선율만).
- 장면표: 하늘이 발소리는 **간이역·숲에서만** 들린다. 강가부터 없다.

## 외부 소리를 받을 때

받기 전에 라이선스를 읽는다. **"AI 관련 사용 금지" 조항부터**, 그다음 상업 사용 가능 여부. 받은 것은 `CREDITS.md`에 적는다.

## 지금 들어 있는 임시 소리

`placeholder/`의 소리는 진짜 소리가 오기 전까지 쓰는 **코드로 만든 임시 소리**다(`tools/placeholder_sound.py`). 외부 에셋이 아니다.
진짜 소리를 넣을 때는 같은 이름의 placeholder 파일을 지운다. 이름이 두 곳에 있으면 도구가 "이름이 겹친다"로 막는다.

---

## 개발: 도구 돌리기

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/audio_import.gd            # 반복 설정·환경음을 맞춘다
godot --headless --path . --script res://tools/audio_import.gd -- --check # 보기만 (스모크 검사에도 들어 있다)
```

- 반복 설정을 고치면 `.import`가 바뀐다. 그 뒤 `--import`와 도구를 한 번 더 돌린다.
- `Sound/Ambience`의 소리 크기(`volume_db`)는 도구가 건드리지 않는다. 장소마다 손으로 맞춘다.
- 오디오 버스는 `AudioServer.add_bus()`로 만들지 않는다. **4.7.2 웹에서도 출력이 끊긴다**(#34에서 확인). `bus_count`를 늘려 만든다.
