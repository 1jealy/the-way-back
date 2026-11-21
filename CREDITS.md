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

## 배경 그림을 만든 AI 도구와 모델

배경 초안은 `tools/art_pipeline/`이 로컬 ComfyUI로 만든다. 아래 모델·도구 파일은 **게임에 들어가지 않는다**(만든 그림만 들어간다). 그래도 생성물을 상업 배포하므로 라이선스를 적어 둔다.
참고 그림(ControlNet 밑그림, IP-Adapter 화풍 참고)은 팀이 만든 것만 쓴다: `assets/art/placeholder/`(코드로 그린 임시 배경), 팀 캐릭터 시트, 같은 장소에서 먼저 뽑아 승인한 층.
프롬프트에 작가 이름을 쓰는 것은 팀 결정(2026-11-21)으로 허용한다. 쓴 작가 이름은 아래 "프롬프트에 쓴 작가" 표에 적는다.

### 프롬프트에 쓴 작가

| 작가 | 쓴 곳(장소·층) | 날짜 |
| --- | --- | --- |
| (아직 없음) | | |

| 쓰임 | 파일 | 만든 이 · 받은 곳 | 라이선스 | 받은 날 | 확인 |
| --- | --- | --- | --- | --- | --- |
| 실행 도구 | ComfyUI 0.46.0 | comfyanonymous · [GitHub](https://github.com/comfyanonymous/ComfyUI) | GPL-3.0 | 2026-11-20 | 도구만 씀. 생성물엔 조건 없음 |
| 체크포인트 (**기본**, `--preset ds`) | `DreamShaperXL_Turbo_v2_1.safetensors` | Lykon · [HF Lykon/dreamshaper-xl-v2-turbo](https://huggingface.co/Lykon/dreamshaper-xl-v2-turbo) | OpenRAIL++ | 2026-11-21 | 상업 사용 가능(사용 제한 조항 준수) |
| 체크포인트 (예전 시험용) | `waiIllustriousSDXL_v170.safetensors` (WAI-illustrious-SDXL v17) | WAI · Civitai (수동으로 받음) | **확인 필요** | 2026-11-21 | 아래 메모 |
| 가속 LoRA (`--preset fast`) | `sdxl_lightning_8step_lora.safetensors` | ByteDance · [HF ByteDance/SDXL-Lightning](https://huggingface.co/ByteDance/SDXL-Lightning) | OpenRAIL++ | 2026-11-20 | 상업 사용 가능(사용 제한 조항 준수) |
| ControlNet | `xinsir-controlnet-union-sdxl-1.0-promax.safetensors` | xinsir · [HF xinsir/controlnet-union-sdxl-1.0](https://huggingface.co/xinsir/controlnet-union-sdxl-1.0) | Apache-2.0 | 2026-11-20 | 상업 사용 가능 |
| 화풍 참고 | `ip-adapter-plus_sdxl_vit-h.safetensors` | h94 · [HF h94/IP-Adapter](https://huggingface.co/h94/IP-Adapter) | Apache-2.0 | 2026-11-20 | 상업 사용 가능 |
| 화풍 참고 | `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | LAION/OpenCLIP · h94/IP-Adapter 안 | MIT | 2026-11-20 | 상업 사용 가능 |
| 업스케일 | `4x_NMKD-Siax_200k.pth` | NMKD · HF 미러 `gemasai/4x_NMKD-Siax_200k` | 미러 표기 "CC0 / Public" | 2026-11-20 | 원 배포처 표기 재확인 필요 |
| 윤곽 추출 | PiDiNet (`table5_pidinet.pth`) | lllyasviel/Annotators · comfyui_controlnet_aux가 받음 | 확인 필요 | 2026-11-21 | 도구 입력용(밑그림 윤곽) |
| 노드 | comfyui_controlnet_aux `c2655d2` | Fannovel16 | Apache-2.0 | 2026-11-20 | |
| 노드 | ComfyUI_IPAdapter_plus `a0f451a` | cubiq | GPL-3.0 | 2026-11-20 | 도구만 씀. 코드를 이 저장소에 넣지 않는다 |
| 노드 | Dazzle-ComfyUI-TiledDiffusion `86a63dd` | DazzleNodes | LICENSE 파일 없음 | 2026-11-20 | 확인 필요 |
| 노드 (지금 기본으로 안 씀) | ComfyUI-RMBG `4d738d2` + BiRefNet-general | 1038lab · ZhengPeng7 | 노드 GPL-3.0 · 모델 MIT | 2026-11-20 | `--alpha-mode birefnet`일 때만 |

- **체크포인트(가장 중요)**: 2026-11-21 기준 Civitai 페이지(<https://civitai.com/models/827184>)를 자동으로 읽지 못해 WAI 자체의 허용 범위를 확인하지 못했다. 바탕 모델 Illustrious-XL은 `fair-ai-public-license-1.0-sd`이고, 모델 카드에 "생성물의 업로드·배포를 제한하지 않는다"고 적혀 있다(돈을 받는 제한은 **모델**을 닫힌 채 팔 때에 대한 것). WAI 페이지의 허용 표시(생성 이미지 상업 사용·판매, "AI 관련 사용 금지" 여부)를 사람이 직접 보고 이 줄을 고친다. **확인 전에는 이 체크포인트로 만든 그림을 공개 빌드에 넣지 않는다.**
- 만든 그림은 손으로 고친 뒤 넣는다. 어느 그림을 어떤 설정(프리셋·시드)으로 뽑았는지는 `tools/art_pipeline/work/<장소>/<층>/`에 남는다.
