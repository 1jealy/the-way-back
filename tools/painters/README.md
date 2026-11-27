# 장소 그리기 (tools/painters)

`python3 tools/placeholder_art.py <place_id>`는 이 폴더에 `<place_id>.py`가 있으면 그 파일의 `paint(width, markers)`로 그린다(없으면 `placeholder_art.py`의 `PAINTERS`).

- 파일 맨 위에서 `import placeholder_art as pa`로 바탕 도구(`pa.Layer`, `pa.ridge`, `pa.paint_clouds`, `pa.finish`, `pa._plume`·`pa._oak` 같은 도우미)를 가져다 쓴다(밑줄 이름은 `import *`로 안 온다).
- `paint`는 층 이름 → `Layer` 사전을 돌려준다. 층: `sky`·`horizon`·`far`·`hills`·`mid`·`near`·`ground`·`props`·`front`(있는 것만).
- 마지막에 `finish(layers, place_id, 해빛 색, 그늘 색)`으로 그림 마무리(질감·빛·흐림, `PAINT` 표)를 건다.
- 화풍 기준은 금빛 들판(`placeholder_art.py`의 `field`): 실루엣 층을 겹치고 멀수록 지평선 빛에 녹이며, 해 쪽 가장자리에 빛.
