# 네스토리(Nestory) — Blender 에셋 의뢰서 (Claude Desktop 전달용)

> Blender MCP(포트 9876)로 아래 에셋을 제작해 주세요. 디자인 배경은 [PRD_Design.md](PRD_Design.md) 참고.
> 결과물은 `Design/Exports/` 아래 폴더 구조로 저장하고, 끝나면 파일 목록과 확인용 미리보기를 알려 주세요.

## 0. 스타일 가이드
- **파스텔 클레이(점토) 인형** 느낌: 매끈하지만 약간 말랑한 표면, 낮은 광택, 은은한 SSS(피부/천).
- 렌더: Cycles(저샘플 + 디노이즈) 또는 EEVEE, 소프트 3점 조명 + 따뜻한 환경광, 부드러운 앰비언트 오클루전.
- 배경: 투명(Film → Transparent), 색 공간 sRGB. 그림자는 별도 레이어가 아니라 **바닥 그림자 없음**(앱에서 처리).
- 형태는 둥글고 두껍게, 날카로운 모서리 금지, 얼굴은 점 눈 + 작은 코/입 + 분홍 볼.
- 팔레트(HEX): cream `#FFF8EF` · peach `#FFB59E` · mint `#A8E0CF` · butter `#FFE08A` · lavender `#CBB8F0` · sky `#B8DDF5` · rose `#F6B6C8` · cocoa `#5A4340`.
- 텍스트/글자 포함 금지.

## 1. 마스코트 "네스티"
- 아기 곰 인형: 큰 둥근 머리, 작은 동그란 귀, 통통한 몸, 크림색 담요를 망토처럼 두름. 몸색은 연한 갈색(밀크 코코아) `#D9B8A3`, 배/주둥이는 크림.
- 표정 7종(각각 PNG): `default`, `smile`, `sleepy`, `eating`, `cheer`, `worried`, `celebrate`.
- 출력: 1024×1024 투명 PNG, 정면 약간 3/4 각도 없음(정면), 캐릭터 높이 약 80%.
- 추가: 기본 표정 **USDZ**(≤ 5MB, 메시 단순, 텍스처 2K 이하) — visionOS 볼륨용. 1m 가 아닌 **약 20cm 실크기**.
- 파일명: `Mascot/nesty_<expression>.png`, `Mascot/nesty.usdz`

## 2. 스티커 9종 (512×512 투명 PNG, 같은 라이팅 조건)
젖병, 기저귀(귀여운 면 기저귀), 딸랑이, 초승달, 별, 구름, 아기 발자국(한 쌍), 하트, 작은 곰인형.
- 파일명: `Stickers/<name>.png` (영문 소문자: `bottle, diaper, rattle, moon, star, cloud, footprints, heart, teddy`)

## 3. 임신 주차 크기 비교 14종 (512×512 투명 PNG)
앱에서 "이번 주 아기는 ○○만 해요"에 쓰는 소품. 클레이 질감, 각각 단순한 점 눈 얼굴 없음(사물 그대로).

| 주차(대표) | 소품 |
|---|---|
| 4 | 양귀비씨 |
| 6 | 렌틸콩 |
| 8 | 산딸기 |
| 10 | 금귤 |
| 12 | 라임 |
| 14 | 레몬 |
| 16 | 아보카도 |
| 20 | 바나나 |
| 24 | 옥수수 |
| 28 | 가지 |
| 32 | 파인애플 |
| 36 | 로메인 상추 |
| 38 | 호박 |
| 40 | 수박 |
- 파일명: `Fruits/week_<NN>_<english>.png` (예: `week_16_avocado.png`)
- 선택(P2): USDZ 버전 `Fruits/week_<NN>_<english>.usdz`, 각 ≤ 3MB.

## 4. 앱 아이콘

### 컨셉
크림→피치 세로 그라데이션(위 `#FFF8EF` → 아래 `#FFB59E`) 배경, 중앙에 네스티 얼굴 정면(캔버스의 약 62%), 이마 위에 작은 버터색 별 1개. 아주 작은 크기에서도 읽히도록 눈·귀·코를 단순화한 버전 사용.

### 산출물 (파일명 고정)
| 파일 | 규격 | 설명 |
|---|---|---|
| `Icons/ios_light_1024.png` | 1024², **전체 사각형, 투명 없음, 모서리 둥글게 하지 않음** | 기본 |
| `Icons/ios_dark_1024.png` | 1024² | 배경만 어둡게(`#2A2423` → `#4A3430`), 마스코트 유지 |
| `Icons/ios_tinted_1024.png` | 1024² | 흑백 알파 실루엣(단색), 시스템이 틴트 적용 |
| `Icons/macos_1024.png` | 1024² 캔버스, 중앙 **824×824 둥근 사각**(연속 곡률), 바깥 투명, 아래쪽 은은한 그림자 | macOS 표준 아이콘 형태 |
| `Icons/visionos_back_1024.png` | 1024², 불투명 | 배경 그라데이션만 |
| `Icons/visionos_mid_1024.png` | 1024², **투명** | 별·구름 등 중간 장식 |
| `Icons/visionos_front_1024.png` | 1024², **투명** | 네스티만 |
| `Icons/layers/` | 1024², 투명 | Icon Composer 용: `bg`, `mascot`, `star` 등 분리 레이어 PNG |
| `Icons/marketing_1024.png` | 1024² | 홍보용(모서리 마스크 없음) |
- macOS 는 위 `macos_1024.png` 하나만 주면 됩니다(크기 파생은 Xcode/스크립트에서 처리). 필요하면 16/32/64/128/256/512 @1x·@2x 도 `Icons/macos_sizes/` 에 내보내 주세요.
- visionOS 는 세 레이어를 겹쳤을 때 시차 효과를 줄 수 있게 **전경과 중간 사이 공간감**(별은 중간, 곰은 전경)을 유지.

## 5. 빈 화면 4장 + 온보딩 3장 (투명 PNG 1200×900)
| 파일 | 구성 |
|---|---|
| `Scenes/empty_records.png` | 네스티가 빈 노트를 들고 있음 |
| `Scenes/empty_schedule.png` | 네스티와 달력 |
| `Scenes/empty_leave.png` | 네스티가 서류 가방과 인사 |
| `Scenes/empty_sidework.png` | 네스티가 노트북 앞에 앉음 |
| `Scenes/onboarding_1.png` | 임신 확인: 네스티가 초음파 사진(추상) 안고 방긋 |
| `Scenes/onboarding_2.png` | 육아 기록: 젖병·기저귀·달 주변에 네스티 |
| `Scenes/onboarding_3.png` | 가족 공유: 큰 곰 2마리(보호자)와 아기 곰 |
- 큰 곰 2마리는 네스티와 같은 스타일(색만 다르게: 연핑크, 연하늘 담요).

## 6. 폴더 구조
```
Design/Exports/
  Mascot/      nesty_*.png, nesty.usdz
  Stickers/    *.png
  Fruits/      week_NN_*.png (+usdz 선택)
  Icons/       ios_*, macos_*, visionos_*, layers/, marketing_1024.png
  Scenes/      empty_*, onboarding_*
  Source/      nestory_assets.blend (원본 .blend 하나)
```

## 7. 품질 체크리스트
- [ ] 모든 PNG 투명 배경 가장자리에 흰 헤일로 없음(프리멀티플라이 알파 확인)
- [ ] 마스코트 표정 7종이 같은 모델·같은 조명
- [ ] 16/29/60pt 로 축소한 아이콘 가독성 확인
- [ ] 다크 배경에 올려도 스티커 가장자리 깨끗
- [ ] USDZ 용량·텍스처 해상도 한도 준수
- [ ] 파일명·폴더 구조 위 규격과 일치
