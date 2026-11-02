# Авторы и лицензии открытых ассетов

Все ассеты — CC0 (общественное достояние), атрибуция не обязательна, но мы благодарим авторов.

## Персонажи (модели и анимации)
- **Quaternius — Ultimate Animated Character Pack** (CC0 1.0): `assets/characters/*.gltf`
  (Casual_Male, Casual_Female, Casual_Bald, Casual2_Male, Casual3_Female, Worker_Male, Worker_Female).
  Скелет и анимации (Idle, Walk, Run, Walk_Carry, Run_Carry, SitDown, Death, Defeat, Victory и др.) — из пака.
  Перекраска материалов (кожа, волосы, одежда), бороды и головные уборы — наш код (`scripts/char_model.gd`).
  https://quaternius.com/packs/ultimatedanimatedcharacter.html

## Текстуры рельефа (ambientCG, CC0 1.0), 1K
- Grass004 → `assets/textures/grass_*.jpg`
- Ground037 → `assets/textures/dirt_*.jpg`
- Rock030 → `assets/textures/rock_*.jpg`
- Ground054 → `assets/textures/sand_*.jpg`
  https://ambientcg.com

## Дом на колёсах
Оригинальная модель, собранная кодом (`scripts/rv.gd`). Не является копией транспорта из других игр.

## Звери (CC0)
- **Quaternius — Ultimate Animated Animals**: олень и самка оленя (`assets/models/animals/stag.gltf`, `deer.gltf`), с анимациями. https://quaternius.com
- **OpenGameArt, Teh_Bucket — «Boar»** (CC0): кабан с анимациями → `boar.glb`. https://opengameart.org/content/boar
- **OpenGameArt, CDmir — «Rabbit»** (CC0): заяц с анимациями → `rabbit.glb`. https://opengameart.org/content/rabbit-0
- **OpenGameArt, STKRudy85 — «White Bear (Low poly)»** (CC0): медведь → `bear.glb`; текстура перекрашена в бурый, кости для движения добавлены нами. https://opengameart.org/content/white-bear-low-poly
- Перевод .blend → .glb (Blender/bpy), материалы и масштаб — наша обработка.

## Природа (CC0)
- **Quaternius — Ultimate Stylized Nature / Stylized Nature MegaKit**: сосны, лиственные деревья, берёзы, сухостой, кусты, папоротник, трава, цветы, грибы, камни → `assets/models/nature/` (текстуры уменьшены до 512–1024 px). https://quaternius.com

## Звуки
Настоящие записи (все CC0, обрезаны, сведены в моно, громкость выровнена скриптом `tools/convert_sounds.py`):
- **The Free Firearm Sound Library** (Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney; через OpenGameArt, CC0): `shot_small` (Ruger Mark III .22), `shot_rifle` (Tikka T3 .30-06), `shot_big` (Mosin Nagant 7.62x54), `shot_shotgun` (Benelli Nova 12 к.). https://opengameart.org/content/the-free-firearm-sound-library
- SpringySpringo — «Gun Reload Sounds»: `reload`. https://opengameart.org/content/gun-reload-sounds
- GGBotNet — «Car Sound Effects Pack»: `engine`, `horn`, `door`. https://opengameart.org/content/car-sound-effects-pack-low-quality
- bart — «Chain winch sounds»: `winch`; «68 workshop sounds»: `hammer`, `ratchet`, `repair`. https://opengameart.org/content/chain-winch-sounds , https://opengameart.org/content/68-workshop-sounds
- rubberduck — «100 CC0 metal and wood SFX»: `thud`, `crash`. https://opengameart.org/content/100-cc0-metal-and-wood-sfx
- qubodup — «Fantozzi's Footsteps»: `step`. https://opengameart.org/content/fantozzis-footsteps-grasssand-stone
- AntumDeluge — «Bear growls» (U.S. Fish & Wildlife Service): `bear_call`. https://opengameart.org/content/bear-growls
- PagDev — «Fireplace sound loop»: `fire`. https://opengameart.org/content/fireplace-sound-loop
- Kresiek The Furry — «Amb rain loop 1»: `rain`. https://opengameart.org/content/amb-rain-loop-1
- Thimras — «Park ambiences» (птицы): `ambience`. https://opengameart.org/content/park-ambiences
- Wolfgang_ — «Crickets ambient noise loopable»: `night`. https://opengameart.org/content/crickets-ambient-noise-loopable
- Остальные звуки (`sounds/`) пока синтезированы нашим `tools/gen_sounds.py`; заменяются файлом с тем же именем.

## Дом на колёсах: текстуры и мебель (CC0)
- **ambientCG** (CC0 1.0), 1K → 512 px: Fabric030, Leather011, Metal032, Metal038, Plastic010, Rubber004, Wood049, Rust004 → `assets/textures/rv/`. https://ambientcg.com
- **Poly Haven** (CC0), 1K: `modern_arm_chair_01`, `sofa_02`, `barrel_stove`, `small_wooden_table_01`, `painted_wooden_cabinet`, `metal_jerrycan`, `metal_toolbox`, `rusted_wheel_rim_01`, `wooden_crate_01` → `assets/models/`. https://polyhaven.com
- Сам кузов, кабина, сиденья, холодильник, стеллаж, багажник и приборы — собраны кодом (`scripts/rv_build.gd`), готовой CC0-модели дома на колёсах найти не удалось.
