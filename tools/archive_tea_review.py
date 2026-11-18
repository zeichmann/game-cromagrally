"""Archive unmodified native screenshots, test evidence and measured FPS, with hashes."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'docs/tea-bend'
BUILD = ROOT / 'build'
BENCHMARKS = ['single_forward_plus_high_circuit', 'single_forward_plus_balanced',
              'four_forward_plus_balanced', 'four_forward_plus_performance']
CAPTURES = ['drive_10', 'drive_15', 'drive_19', 'drive_24', 'drive_29', 'drive_35',
            'bend_overview', 'teahouse', 'house_front', 'stream_bridge', 'garden',
            'stone_arch', 'ancient_oak', 'stream_close', 'teapot_sign',
            'gpu_leaves', 'gpu_sign', 'gpu_water']
LOGS = {'tea_test_rules.log': 'RULE_TEST PASS', 'tea_test_art.log': 'ART_TEST PASS',
        'tea_test_environment.log': 'ENVIRONMENT_TEST PASS',
        'tea_test_living.log': 'LIVING_TEST PASS',
        'tea_test_geometry_final.log': 'TEA_BEND_TEST PASS',
        'tea_test_session.log': 'SESSION_TEST PASS',
        'tea_full_race.log': 'RACE_TEST PASS',
        'tea_gpu_test.log': 'TEA_GPU_TEST PASS',
        'tea_final_test_gpu_motion.log': 'GPU_MOTION_TEST PASS',
        'tea_final_test_gpu_skin.log': 'GPU_SKIN_TEST PASS',
        'tea_final_test_gpu_life.log': 'GPU_LIFE_TEST PASS',
        'tea_final_review_tea_bend.log': 'TEA_REVIEW PASS',
        'tea_final_review_tour.log': 'TOUR_RETURN PASS',
        'tea_final_focused_tour.log': 'TOUR_RETURN PASS',
        'tea_fixed_benchmark.log': 'TEA_FIXED PASS'}


def archive():
    image_folder = FOLDER / 'screenshots'
    image_folder.mkdir(parents=True, exist_ok=True)
    evidence = {}
    for name, marker in LOGS.items():
        content = (BUILD / name).read_text(encoding='utf-8')
        assert marker in content, name
        assert not re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)', content), name
        evidence[name] = content
    (FOLDER / 'TEST_LOGS.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline=chr(10))
    paths = []
    for name in CAPTURES:
        destination = image_folder / (name + '.png')
        shutil.copyfile(BUILD / 'tea-review' / destination.name, destination)
        paths.append(destination)
    measurements = []
    for name in BENCHMARKS:
        source = BUILD / 'art-review' / (name + '.json')
        assert source.stat().st_mtime > (ROOT / 'assets/tea_bend/teahouse.res').stat().st_mtime
        data = json.loads(source.read_text())
        assert data['world_instance_layout_valid'] and data['instance_layout_valid']
        assert data['gpu_pose_generation'] and not data['root_camera_active'] and data['samples'] > 100
        measurements.append(data)
        destination = ROOT / 'docs/benchmarks' / ('tea_' + name + '.json')
        shutil.copyfile(source, destination)
        paths.append(destination)
    assert measurements[0]['completed_laps'] >= 1 and all(measurements[0]['adventure_observed'].values())
    fixed_path = BUILD / 'tea-review/fixed_camera_benchmarks.json'
    fixed = json.loads(fixed_path.read_text())
    assert fixed['gpu_motion_initialized'] and len(fixed['results']) == 6
    shutil.copyfile(fixed_path, FOLDER / fixed_path.name)
    for result in fixed['results']:
        destination = image_folder / result['screenshot']
        shutil.copyfile(BUILD / 'tea-review' / destination.name, destination)
        paths.append(destination)
    paths += sorted((ROOT / 'assets/tea_bend').glob('*.res'))
    paths += [ROOT / 'assets/textures/tea_ancient_bark_v1.png', ROOT / 'tools/tea_asset_builder.gd',
              ROOT / 'scripts/tea_bend.gd', ROOT / 'scripts/tea_bend_layout.gd',
              ROOT / 'scripts/tea_geometry.gd', FOLDER / 'BARK_PROMPT.txt',
              FOLDER / 'TEST_LOGS.json', FOLDER / fixed_path.name]
    paths += sorted((ROOT / 'shaders').glob('tea_*.gdshader'))
    texture = ROOT / 'assets/textures/tea_ancient_bark_v1.png'
    width, height = struct.unpack('>II', texture.read_bytes()[16:24])
    manifest = {'recorded_utc': datetime.now(timezone.utc).isoformat(),
                'geometry': 'Original local authored meshes and offline LOD generation; no external 3D models.',
                'bitmap': {'path': texture.relative_to(ROOT).as_posix(), 'width': width, 'height': height,
                           'method': 'Built-in image_gen, text prompt only; copied without editing or upscaling.'},
                'captures': 'Unmodified native Godot output, copied byte for byte.',
                'files': [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                           'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]}
    (FOLDER / 'ASSET_MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline=chr(10))
    race_rows = '\n'.join(f"| {label} | {r['mean_fps']:.2f} | {r['frame_ms_p99']:.2f} | {r['frame_ms_max']:.2f} |" for label, r in zip(
        ['High, 1 widok, pełne okrążenie', 'Balanced, 1 widok, krótka próba', 'Balanced, 4 widoki', 'Performance, 4 widoki'], measurements))
    fixed_rows = '\n'.join(f"| {r['camera']} | {r['profile']} | {r['mean_fps']:.2f} | {r['frame_ms_p99']:.2f} |" for r in fixed['results'])
    preparation = ', '.join(f"{r['startup_preparation_ms']/1000:.2f} s" for r in measurements)
    report = '''# Zakręt przy herbaciarni

Nowy fragment rzeczywistej trasy: herbaciarnia z giętym dachem i wykuszem, stary dąb, most drogowy, kładka, strumień oraz taras. **Run-teahouse.cmd** zapętla cztery ujęcia tego miejsca. **Esc** wraca do menu, **M** wycisza dźwięk. Zwykły objazd wyspy ma teraz 16 ujęć, a przygotowanie grafiki 20 widoków w trzech profilach.

![Herbaciarnia i dąb](screenshots/teahouse.png)

![Rzeczywista kamera kierowcy](screenshots/drive_19.png)

## Geometria i materiały

Cztery osobne zapisane modele z LOD: herbaciarnia, dąb, taras i szyld. Herbaciarnia ma dachówki z grubością, zamknięte poddasze i podbicie dachu, trzyczęściowy wykusz, okna także od strumienia, okiennice, donice, drzwi z okuciami, gięty komin, rynny oraz szyld z dzbankiem na metalowym wsporniku. Taras ma stoliki, krzesła, dzbanki i filiżanki. [Liczby geometrii](../../assets/tea_bend/mesh_manifest.json).

Dąb ma wygięty pień, korzenie, 18 rozgałęzionych skupisk i 4 680 pojedynczych profilowanych liści. Kora używa nowego albedo 1254×1254 px z wbudowanego image_gen. Obraz zachowano w natywnym rozmiarze; nie jest oznaczany jako 2K/4K. [Dokładny prompt](BARK_PROMPT.txt), [plik tekstury](../../assets/textures/tea_ancient_bark_v1.png).

Droga zwęża się stopniowo do mostu. Dwa kamienne boki podążają za rzeczywistymi punktami i szerokością drogi; przęsło zostawia otwarty przepływ wody. Węższa drewniana kładka prowadzi w stronę drzewa. Strumień ma obniżone koryto w głównej siatce terenu i osobną, gęściej próbkowaną powierzchnię brzegów. Odpływ opada do morza; początek ukrywa skała źródła. Starsze domki, drzewa i ogrodzenia są wyłączone z rezerwowanego obszaru. Mieszkańcy stoją na tarasie i suchych brzegach; trzy kaczki przeniesiono do spokojnego odcinka potoku.

![Strumień i kamienne przęsło](screenshots/stone_arch.png)

## GPU i pauza

Liście reagują na wiatr w shaderze wierzchołków. Szyld kołysze shader wokół punktu zawieszenia. Strumień ma przesuwający się nurt, pianę przy brzegach i drobne fale; normalne zachowują kierunek nachylonego odpływu. Ruch korzysta ze wspólnego zegara GPU, zatrzymywanego podczas pauzy. Para nad dzbankiem i kominem, spadające liście oraz drobne świetliki są GPUParticles3D.

Węzeł dzielnicy nie ma skryptu aktualizującego transformacje co klatkę. Fizyka samochodów, AI, kolizje, kamery, dźwięk i UI nadal działają na CPU. Geometria modeli i LOD powstaje offline; koryto terenu, instancje i statyczne elementy mostu są przygotowywane przy wczytaniu. Nie jest to generowanie wszystkich modeli przez GPU w czasie jazdy. Woda jest efektem dekoracyjnym, bez fizycznej symulacji płynu.

## Walidacja

- Reguły 133 PASS, otoczenie 271 PASS, grafika PASS, żywa trasa 23 PASS, nowy zakręt 12 PASS, sesja 40 PASS.
- Kontrola zakrętu: poprawne siatki i normalne, zwrot dachówek ku górze, brak przesuniętych części mostu, przejazd pod gałęziami, rozsądny spadek drogi, suche miejsca mieszkańców i minimum 1,185 m między środkiem strumienia a próbkowanym dnem.
- Pełny wyścig: sześć AI ukończyło po trzy legalne okrążenia, ostatni czas symulacji 105,50 s przy kroku 1/60 s.
- GPU motion 125 PASS; GPU skin sześć siatek PASS; GPU life 11 PASS, w tym siedem zapętlonych źródeł audio i jeden słuchacz.
- Nowy GPU test 9 PASS: widoczny ruch liści, szyldu i nurtu, dokładne zamrożenie ich obrazu, widoczna symulacja pary oraz produkcyjna pauza i wznowienie cząsteczek.
- 15 natywnych ujęć trasy i detali. Objazd całej wyspy: 16 ujęć; objazd herbaciarni: cztery; oba wracają Esc do aktywnego menu.

[Zachowane logi](TEST_LOGS.json) i [hashe plików](ASSET_MANIFEST.json). W teście GPU skin usunięto zbędne przywracanie ukrytego świata 3D na jedną klatkę przed zamknięciem. Wcześniej powodowało zawieszenie po poprawnym zakończeniu porównań; powtórzona próba zakończyła się kodem 0.

## Płynność

Windows, Godot 4.7.2, Vulkan / Forward+, Intel Iris Xe, okno 1280×800, bez VSync i limitu FPS. Wszystkie próby natywne wykonano kolejno, bez drugiej instancji gry. Odczyty obrazu i zapis PNG są poza pomiarem. Przygotowanie grafiki, pierwsze dwie klatki i pięć sekund rozgrzewki są wyłączone z pomiaru jazdy.

| Jazda | Średnie FPS | p99, ms | Maksimum, ms |
|---|---:|---:|---:|
''' + race_rows + '''

Pierwsza kontrola nowego objazdu wymagała 33,53 s przygotowania wariantów grafiki. Późniejsze próby jazdy z pamięcią podręczną: ''' + preparation + '''. Liczniki kompilacji podczas pomiaru nadal są niezerowe; ich wartości zachowano w surowych JSON. To nie są próby całkowicie wolne od kompilacji w czasie jazdy.

Poniższa osobna próba izoluje koszt nowego miejsca: nieruchoma kamera, jeden nieruchomy widoczny pojazd w widoku drive, brak AI i fizyki pojazdów. To pomiar renderowania, nie FPS wyścigu. Każdy przypadek obejmuje dwie sekundy rozgrzewki i cztery sekundy pomiaru po przygotowaniu grafiki.

| Kamera | Profil | Średnie FPS | p99, ms |
|---|---|---:|---:|
''' + fixed_rows + '''

[Surowe pomiary nieruchomych kamer](fixed_camera_benchmarks.json). Surowe próby jazdy są w docs/benchmarks z prefiksem tea_. Wyniki dotyczą tej Iris Xe i tych ustawień; nie potwierdzają stałych 60 FPS ani docelowej wydajności 1080p. Warstwa artystyczna i płynność pozostają do dalszej oceny.

## Odtworzenie

```powershell
godot --headless --editor --single-threaded-scene --path . --import --quit
godot --headless --path . --script tools/build_tea_assets.gd
godot --headless --path . --script tests/test_tea_bend.gd
godot --path . --script tests/test_tea_gpu.gd
godot --path . --script tools/review_tea_bend.gd
godot --path . --script tools/benchmark_tea_bend.gd
godot --path . -- --tea-tour
```

Gotowe modele i tekstura są w repozytorium. Zwykłe uruchomienie nie wykonuje budowania modeli offline. [Pochodzenie całej gry](../PROVENANCE.md), [poprzedni przyrost](../GRAPHICS_VALIDATION_LIVING.md).
'''
    (FOLDER / 'README.md').write_text(report, encoding='utf-8', newline=chr(10))
    old = ROOT / 'docs/GRAPHICS_VALIDATION.md'
    backup = ROOT / 'docs/GRAPHICS_VALIDATION_LIVING.md'
    if not backup.exists():
        shutil.copyfile(old, backup)
    old.write_text('# Bieżąca walidacja grafiki\n\nNajnowszy przyrost: [zakręt przy herbaciarni — obrazy, GPU, testy i pomiary](tea-bend/README.md).\n\nZachowany [raport żywej wyspy sprzed przebudowy zakrętu](GRAPHICS_VALIDATION_LIVING.md) oraz [wcześniejszy raport](GRAPHICS_VALIDATION_BEFORE_LIVING.md).\n', encoding='utf-8', newline=chr(10))
    print('TEA_ARCHIVE', len(paths), 'hashed files;', len(CAPTURES), 'native captures; 4 race and 6 fixed-camera cases')


if __name__ == '__main__':
    archive()
