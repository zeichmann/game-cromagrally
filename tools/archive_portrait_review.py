"""Archive native character renders, successful checks and current measurements."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
FOLDER = ROOT / 'docs/portraits-v3'
CAPTURES = [f'{actor}_{view}' for actor in ['zabol', 'swinka']
            for view in ['front', 'threequarter', 'profile', 'face']]
CAPTURES += [f'{actor}_{view}' for actor in ['rabbit', 'mouse']
             for view in ['threequarter', 'face']]
CAPTURES += ['cockpit_pair', 'cockpit_zabol', 'cockpit_swinka',
             'drive_visibility', 'villagers_in_game']
GPU_CAPTURES = ['living_blink_open', 'living_blink_closed']
GPU_CAPTURES += ['living_gpu_' + animal for animal in ['rabbit', 'mouse', 'cat', 'gull', 'duck']]
BENCHMARKS = ['single_forward_plus_high_circuit', 'single_forward_plus_balanced',
              'four_forward_plus_performance']
LOGS = {
    'portrait-assets-5.log': 'PORTRAIT_DRIVERS PASS',
    'portrait-resident-final.log': 'PORTRAIT_RESIDENTS PASS',
    'portrait-test-assets.log': 'PORTRAIT_ASSET_TEST PASS',
    'portrait_test_art.log': 'ART_TEST PASS',
    'portrait_test_environment.log': 'ENVIRONMENT_TEST PASS',
    'portrait_test_living.log': 'LIVING_TEST PASS',
    'portrait_test_tea_bend.log': 'TEA_BEND_TEST PASS',
    'portrait_test_session.log': 'SESSION_TEST PASS',
    'portrait_full_race.log': 'RACE_TEST PASS',
    'portrait_test_gpu_motion.log': 'GPU_MOTION_TEST PASS',
    'portrait_test_gpu_skin.log': 'GPU_SKIN_TEST PASS',
    'portrait_test_gpu_life.log': 'GPU_LIFE_TEST PASS',
    'portrait-review-4.log': 'PORTRAIT_REVIEW PASS',
    'portrait-game-review-2.log': 'CHARACTER_GAME_REVIEW PASS',
}


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                    encoding='utf-8', newline=chr(10))


def archive():
    screenshots = FOLDER / 'screenshots'
    screenshots.mkdir(parents=True, exist_ok=True)
    evidence = {}
    for name, marker in LOGS.items():
        content = (BUILD / name).read_text(encoding='utf-8')
        assert marker in content, name
        assert not re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)', content), name
        evidence[name] = content
    write_json(FOLDER / 'TEST_LOGS.json', evidence)
    paths = [FOLDER / 'TEST_LOGS.json']
    for source_folder, names in [('portrait-review', CAPTURES), ('art-review', GPU_CAPTURES)]:
        for name in names:
            destination = screenshots / (name + '.png')
            shutil.copyfile(BUILD / source_folder / destination.name, destination)
            paths.append(destination)
    newest_mesh = max(p.stat().st_mtime for p in (ROOT / 'assets/characters/portrait_v3').glob('*.res'))
    newest_mesh = max(newest_mesh, (ROOT / 'assets/fairytale/resident_mouse.res').stat().st_mtime,
                      (ROOT / 'assets/fairytale/resident_rabbit.res').stat().st_mtime)
    measurements = []
    for name in BENCHMARKS:
        source = BUILD / 'art-review' / (name + '.json')
        assert source.stat().st_mtime > newest_mesh, name
        data = json.loads(source.read_text())
        assert data['gpu_pose_generation'] and data['graphics_prepared']
        assert data['instance_layout_valid'] and data['world_instance_layout_valid']
        assert not data['root_camera_active'] and data['samples'] > 100
        measurements.append(data)
        destination = ROOT / 'docs/benchmarks' / ('portraits_' + name + '.json')
        shutil.copyfile(source, destination)
        paths.append(destination)
    assert measurements[0]['completed_laps'] >= 1
    assert all(measurements[0]['adventure_observed'].values())
    paths += sorted((ROOT / 'assets/characters/portrait_v3').glob('*.res'))
    paths += [ROOT / 'assets/characters/portrait_v3/mesh_manifest.json',
              ROOT / 'assets/fairytale/resident_rabbit.res', ROOT / 'assets/fairytale/resident_mouse.res',
              ROOT / 'assets/fairytale/mesh_manifest.json']
    paths += [ROOT / name for name in [
        'tools/portrait_geometry.gd', 'tools/portrait_character_builder.gd',
        'tools/portrait_resident_builder.gd', 'tools/build_portrait_residents.gd',
        'tools/fairy_asset_builder.gd', 'tools/review_portraits.gd',
        'tools/review_character_game.gd', 'tools/archive_portrait_review.py',
        'tests/test_portrait_assets.gd', 'tests/test_gpu_skin.gd',
        'scripts/driver_art.gd', 'scripts/vehicle_art.gd', 'shaders/palette_surface.gdshaderinc']]
    manifest = {
        'recorded_utc': datetime.now(timezone.utc).isoformat(),
        'geometry': 'Original local authored meshes; six driver variants and two villagers.',
        'references': 'Academia Oli canonical portraits retained in docs/character-lookdev-v2/.',
        'bitmap_assets_added': False,
        'captures': 'Unmodified native Godot output, copied byte for byte.',
        'files': [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                   'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths],
    }
    write_json(FOLDER / 'ASSET_MANIFEST.json', manifest)
    rows = '\n'.join(f"| {label} | {r['mean_fps']:.2f} | {r['frame_ms_p99']:.2f} | {r['frame_ms_max']:.2f} |"
                     for label, r in zip(['High, pełne okrążenie, 1 widok',
                                          'Balanced, krótka próba, 1 widok',
                                          'Performance, 4 widoki'], measurements))
    report = '''# Postacie — portrety 3D, etap v3

2026-11-17: przebudowane twarze i stroje Żabola oraz Świnki, a także królik i mysz z wioski. Obrazy poniżej pochodzą z natywnego renderera gry. Nie są ilustracjami koncepcyjnymi ani retuszowanymi wizualizacjami.

| Model | Poprzednia siatka | Nowa siatka |
|---|---|---|
| Żabol | [Przed](../screenshots/living_driver_zabol_threequarter.png) | [Teraz](screenshots/zabol_threequarter.png) |
| Świnka | [Przed](../screenshots/living_driver_swinka_threequarter.png) | [Teraz](screenshots/swinka_threequarter.png) |

![Kierowcy w rzeczywistych kokpitach](screenshots/cockpit_pair.png)

![Świnka — zbliżenie nowej siatki](screenshots/swinka_face.png)

## Zakres

Głowy mają jawne pierścienie geometrii wokół ust i ciągłe policzki. Zastąpiły wcześniejszą ekstrakcję powierzchni niejawnej, która dawała poszarpane wargi. Białka, brązowe tęczówki, źrenice i powieki przylegają do kształtu twarzy. Świnka ma osobny owalny ryjek z dwoma zagłębionymi nozdrzami, miękkie uszy o zamkniętej grubości i kokardę. Żabol zachowuje szeroką głowę, żuchwę i naturalne wyniosłości oczu.

Stroje mają dopasowane klapy, lamówki, guziki, mankiety i palce przy kierownicy. Żabol ma skórzany pas z otwartą złotą klamrą; Świnka kremowy żabot. Czarne filcowe kapelusze mają złote brzegi oraz kotwicę lub emblemat świnki. Żagiel przesunięto i zwężono, aby odsłonić kierowcę.

Królik i mysz dostały nowe ciągłe pyski, oczy i powieki, wąsy, ubrania, dłonie oraz buty. Królik nosi torbę listonosza, mysz fartuch. Zachowano rozmieszczenie mieszkańców i role. Koty, kaczki i mewy używają dotychczasowych modeli.

![Mieszkańcy przy herbaciarni](screenshots/villagers_in_game.png)

[Pełny opis modeli i liczby geometrii](../CHARACTERS.md). [Poprzednie modele](../CHARACTERS_BEFORE_PORTRAITS.md) i [referencje](../character-lookdev-v2/README.md) pozostają zachowane. Nowe modele wymagają oceny artystycznej użytkownika; testy nie potwierdzają idealnego podobieństwa do portretów.

## GPU

Sześć kości kierowcy: compute shader oblicza pozy, shader wierzchołków deformuje siatki. Żuchwa i oczy mają sztywną wagę głowy, więc nie zostają przy tułowiu podczas skrętu. Chusta ma dwa osobne przeguby. Mruganie i ruch powiek kierowców oraz nowych mieszkańców korzystają z zatrzymywanego zegara GPU. Tęczówki, drobna faktura skóry, filcu i tkanin są wyliczane w shaderze.

Nie ma aktualizacji twarzy przez CPU co klatkę, aktywnego Skeleton3D ani odczytu póz w grze. Modele i LOD powstają offline w narzędziach GDScript. Fizyka, AI, kamery i UI nadal działają na CPU. Mimika obejmuje stały uśmiech i mruganie; nie dodano animacji mowy.

## Sprawdzenie

- Nowy test modeli: 16 asercji PASS, w tym podążanie żuchwy za głową, zachowane części twarzy we wszystkich profilach, prawdziwe kieszenie nozdrzy i widoczność głowy za żaglem.
- Grafika PASS; otoczenie 271 PASS; żywa trasa 23 PASS; herbaciarnia 12 PASS; sesja 40 PASS.
- Sześć AI ukończyło trzy uporządkowane okrążenia przy kroku fizyki 1/60 s.
- GPU motion: 125 asercji PASS. GPU skin: sześć porównań obrazów PASS. GPU life: 11 asercji PASS, w tym widoczny ruch pięciu gatunków, mruganie, pauza i wznowienie.
- 12 natywnych ujęć modeli: przód, trzy czwarte, profil i twarz dwóch kierowców oraz dwie kamery królika i myszy. Dodatkowo pięć widoków z gry i siedem obrazów kontroli animacji.

Test GPU skin izoluje atlas póz i modele od całej sceny wyścigu. Zwalnianie ostatniego pomocniczego viewportu podczas klatki powodowało zawieszenie Iris Xe po poprawnych porównaniach. Zasoby zwalnia teraz zamknięcie SceneTree; powtórzony test zakończył się kodem 0. [Zachowane końcowe logi](TEST_LOGS.json), [SHA-256 źródeł, modeli i obrazów](ASSET_MANIFEST.json).

## Płynność

Windows, Godot 4.7.2, Vulkan / Forward+, Intel Iris Xe, 1280×800. Próby wykonywane kolejno, bez drugiej gry, bez VSync i limitu FPS. Przygotowanie grafiki, pierwsze dwie klatki oraz pięć sekund rozgrzewki są poza pomiarem; zapis PNG także. High mierzy około 40 s jazdy, pozostałe około 12 s. Krótszych prób i różnych profili nie należy traktować jako bezpośredniego porównania.

| Próba | Średnie FPS | p99, ms | Maksimum, ms |
|---|---:|---:|---:|
''' + rows + '''

Surowe JSON są w `docs/benchmarks/portraits_*.json`, wraz z liczbą próbek, rozdzielczością widoków i kompilacjami shaderów. Wyniki dotyczą tej Iris Xe i tych ustawień; nie potwierdzają stałych 60 FPS ani wydajności 1080p. [Pomiary poprzedniego etapu](../tea-bend/README.md) pozostają oddzielnie.

## Odtworzenie

```powershell
godot --headless --editor --single-threaded-scene --path . --import --quit
godot --headless --path . --script tools/portrait_character_builder.gd
godot --headless --path . --script tools/build_portrait_residents.gd
godot --headless --path . --script tests/test_portrait_assets.gd
godot --path . --script tools/review_portraits.gd
godot --path . --script tools/review_character_game.gd
godot --path . --script tests/test_gpu_skin.gd
godot --path . --script tests/test_gpu_life.gd
python tools/archive_portrait_review.py
```

Archiwizację należy wykonać po pełnym zestawie testów i trzech pomiarach z nazwami logów z narzędzia. Zwykła gra ładuje gotowe zasoby. Nie dodano nowych bitmap ani zewnętrznych modeli, nie wysyłano artworku do usług 3D. [Pochodzenie projektu](../PROVENANCE.md).
'''
    (FOLDER / 'README.md').write_text(report, encoding='utf-8', newline=chr(10))
    print('PORTRAIT_ARCHIVE', len(paths), 'hashed files;', len(CAPTURES) + len(GPU_CAPTURES),
          'native captures; three current race measurements')


if __name__ == '__main__':
    archive()
