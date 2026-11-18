"""Archive unretouched native v5 renders, checks, textures and measurements."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
FOLDER = ROOT / 'docs/academy-v5'
GALLERY = [f'{actor}_{view}' for actor in ['zabol', 'swinka'] for view in
           ['front', 'threequarter', 'profile', 'face', 'calm', 'joy', 'blink', 'gaze']]
GALLERY += ['duo_faces']
EYES = [f'test_{actor}_{detail}_{state}' for actor in range(2)
        for detail in range(3) for state in ['open', 'closed']]
EYES += [f'cornea_{actor}_{state}' for actor in range(2) for state in ['enabled', 'disabled']]
GAME = ['cockpit_pair', 'cockpit_zabol', 'cockpit_swinka', 'drive_visibility', 'villagers_in_game']
BENCHMARKS = ['single_forward_plus_high_circuit', 'single_forward_plus_balanced',
              'four_forward_plus_performance']
LOGS = {
    'organic_build_final.log': 'ORGANIC_DRIVERS PASS',
    'organic_test_art.log': 'ART_TEST PASS',
    'organic_test_portrait_assets.log': 'PORTRAIT_ASSET_TEST PASS',
    'organic_test_organic_assets.log': 'ORGANIC_ASSET_TEST PASS',
    'organic_test_session.log': 'SESSION_TEST PASS',
    'organic_face_test.log': 'ACADEMY_FACE_TEST PASS',
    'organic_review_final.log': 'ORGANIC_REVIEW PASS',
    'organic_game_review.log': 'CHARACTER_GAME_REVIEW PASS',
    'organic_test_gpu_motion.log': 'GPU_MOTION_TEST PASS',
    'organic_test_gpu_skin.log': 'GPU_SKIN_TEST PASS',
    'organic_test_gpu_life.log': 'GPU_LIFE_TEST PASS',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n',
                    encoding='utf-8', newline=chr(10))


def archive():
    images = FOLDER / 'screenshots'
    images.mkdir(parents=True, exist_ok=True)
    evidence = {}
    for name, marker in LOGS.items():
        content = (BUILD / name).read_text(encoding='utf-8')
        assert marker in content and not re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)', content), name
        evidence[name] = content
    write_json(FOLDER / 'TEST_LOGS.json', evidence)
    paths = [FOLDER / 'TEST_LOGS.json', FOLDER / 'TEXTURE_PROMPTS.json']
    textures = json.loads((FOLDER / 'TEXTURE_PROMPTS.json').read_text(encoding='utf-8'))
    for entry in textures['assets']:
        path = ROOT / entry['destination']
        content = path.read_bytes()
        assert content[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', content[16:24]) == (1254, 1254)
        original = Path(entry['source'])
        if original.exists():
            assert sha(path) == sha(original), entry['key']
        paths += [path, Path(str(path) + '.import')]
    pose_source = BUILD / 'validated_skin_poses.json'
    poses = json.loads(pose_source.read_text())
    assert poses['shader_sha256'] == sha(ROOT / 'shaders/gpu_motion.glsl')
    shutil.copyfile(pose_source, FOLDER / 'GPU_POSES.json')
    paths.append(FOLDER / 'GPU_POSES.json')
    newest = max(p.stat().st_mtime for p in (ROOT / 'assets/characters/academy_v5').glob('*.res'))
    shader_paths = [ROOT / name for name in ['shaders/gpu_motion.glsl',
                    'shaders/academy_face.gdshaderinc', 'shaders/academy_cornea.gdshader',
                    'shaders/driver_deformation.gdshaderinc', 'shaders/palette_surface.gdshaderinc']]
    newest_shader = max(p.stat().st_mtime for p in shader_paths)
    for source_folder, names in [('organic-review', GALLERY), ('academy-review', EYES),
                                 ('portrait-review', GAME)]:
        for name in names:
            source = BUILD / source_folder / (name + '.png')
            assert source.stat().st_mtime > max(newest, newest_shader), name
            destination = images / source.name
            shutil.copyfile(source, destination)
            paths.append(destination)
    measurements = []
    for name in BENCHMARKS:
        source = BUILD / 'art-review' / (name + '.json')
        assert source.stat().st_mtime > max(newest, newest_shader), name
        data = json.loads(source.read_text())
        assert data['gpu_pose_generation'] and data['graphics_prepared']
        assert data['instance_layout_valid'] and data['world_instance_layout_valid']
        assert not data['root_camera_active'] and data['samples'] > 100
        measurements.append(data)
        destination = ROOT / 'docs/benchmarks' / ('organic_' + name + '.json')
        shutil.copyfile(source, destination)
        paths.append(destination)
    assert measurements[0]['completed_laps'] >= 1
    paths += sorted((ROOT / 'assets/characters/academy_v5').glob('*'))
    paths += shader_paths
    paths += [ROOT / name for name in [
        'tools/organic_character_builder.gd', 'tools/organic_face_geometry.gd',
        'tools/academy_character_builder.gd', 'tools/academy_face_geometry.gd',
        'tools/review_organic_faces.gd', 'tools/review_character_game.gd',
        'tools/archive_organic_review.py', 'scripts/driver_art.gd',
        'tests/test_academy_faces.gd', 'tests/test_organic_assets.gd',
        'tests/test_gpu_motion.gd', 'tests/test_gpu_skin.gd', 'tests/test_gpu_life.gd',
        'tests/test_portrait_assets.gd', 'tests/test_art.gd',
        'docs/character-lookdev-v2/canonical-swinka.webp',
        'docs/character-lookdev-v2/canonical-zabol.webp']]
    write_json(FOLDER / 'ASSET_MANIFEST.json', {
        'recorded_utc': datetime.now(timezone.utc).isoformat(),
        'source': 'Local authored 3D geometry based on retained Academia Oli portraits; original material PNGs from built-in image_gen text prompts.',
        'capture_method': 'Unmodified native Godot output; copied byte for byte.',
        'texture_method': textures['method'],
        'likeness_status': 'Visual comparison provided for user assessment; tests do not certify likeness.',
        'files': [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                   'sha256': sha(p)} for p in paths],
    })
    table = '\n'.join(f"| {label} | {r['mean_fps']:.2f} | {r['frame_ms_p99']:.2f} | {r['frame_ms_max']:.2f} |"
                      for label, r in zip(['High, 1 widok, pełne okrążenie',
                                           'Balanced, 1 widok, krótka próba',
                                           'Performance, 4 widoki'], measurements))
    report = FOLDER / 'README.md'
    text = report.read_text(encoding='utf-8')
    text = re.sub(r'<!-- MEASUREMENTS -->.*?<!-- /MEASUREMENTS -->',
                  '<!-- MEASUREMENTS -->\n| Próba | Średnie FPS | p99, ms | Maksimum, ms |\n'
                  '|---|---:|---:|---:|\n' + table + '\n<!-- /MEASUREMENTS -->', text, flags=re.S)
    report.write_text(text, encoding='utf-8', newline=chr(10))
    print('ORGANIC_ARCHIVE', len(paths), 'hashed files;', len(GALLERY) + len(EYES) + len(GAME), 'native renders')


if __name__ == '__main__':
    archive()
