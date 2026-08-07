from pathlib import Path

CACHE = Path('.godot/global_script_class_cache.cfg')
SENTINELS = [
    'MasteredWeaponFighterController',
    'ProvisionalSpritePresenter',
    'CharacterVisualCatalog',
    'CharacterAttachmentCatalog',
    'TechniqueAttachmentCatalog',
    'TechniqueVisualTimeline',
    'CosmeticSocketCatalog',
    'BattleLoadoutCatalog',
    'BuildProfile',
    'FighterController',
]

if not CACHE.exists():
    raise SystemExit('GLOBAL_CLASS_REGISTRY=FAIL missing .godot/global_script_class_cache.cfg')

text = CACHE.read_text(encoding='utf-8', errors='replace')
missing = [name for name in SENTINELS if name not in text]
if missing:
    raise SystemExit('GLOBAL_CLASS_REGISTRY=FAIL missing=' + ','.join(missing))

print(f'GLOBAL_CLASS_REGISTRY=PASS sentinels={len(SENTINELS)}')
