"""Preserve original native renders, successful checks and measurements for v4."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
FOLDER = ROOT / 'docs/academy-v4'
PORTRAITS = [actor + '_' + view for actor in ['zabol', 'swinka'] for view in
             ['front', 'threequarter', 'profile', 'face', 'calm', 'joy', 'blink', 'gaze']]
PORTRAITS += ['duo_faces']
PORTRAITS += [f'test_{actor}_{detail}_{state}' for actor in range(2)
              for detail in range(3) for state in ['open', 'closed']]
GAME = ['cockpit_pair', 'cockpit_zabol', 'cockpit_swinka', 'drive_visibility']
BENCHMARKS = ['single_forward_plus_high_circuit', 'single_forward_plus_balanced',
              'four_forward_plus_performance']
LOGS = {
    'academy_v4_build_4.log': 'ACADEMY_DRIVERS PASS',
    'academy_v4_test_art.log': 'ART_TEST PASS',
    'academy_v4_test_portrait_assets.log': 'PORTRAIT_ASSET_TEST PASS',
    'academy_v4_test_session.log': 'SESSION_TEST PASS',
    'academy_v4_face_test.log': 'ACADEMY_FACE_TEST PASS',
    'academy_v4_review_final.log': 'ACADEMY_REVIEW PASS',
    'academy_v4_game_review.log': 'CHARACTER_GAME_REVIEW PASS',
    'academy_v4_gpu_motion.log': 'GPU_MOTION_TEST PASS',
    'academy_v4_gpu_skin.log': 'GPU_SKIN_TEST PASS',
    'academy_v4_gpu_life.log': 'GPU_LIFE_TEST PASS',
}


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
    paths = [FOLDER / 'TEST_LOGS.json']
    pose_source = BUILD / 'validated_skin_poses.json'
    poses = json.loads(pose_source.read_text())
    assert poses['shader_sha256'] == hashlib.sha256((ROOT / 'shaders/gpu_motion.glsl').read_bytes()).hexdigest()
    shutil.copyfile(pose_source, FOLDER / 'GPU_POSES.json')
    paths.append(FOLDER / 'GPU_POSES.json')
    newest = max(p.stat().st_mtime for p in (ROOT / 'assets/characters/academy_v4').glob('*.res'))
    newest_shader = max((ROOT / name).stat().st_mtime for name in
                        ['shaders/gpu_motion.glsl', 'shaders/academy_face.gdshaderinc',
                         'shaders/palette_surface.gdshaderinc'])
    for source_folder, names in [('academy-review', PORTRAITS), ('portrait-review', GAME)]:
        for name in names:
            source = BUILD / source_folder / (name + '.png')
            assert source.stat().st_mtime > newest, name
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
        destination = ROOT / 'docs/benchmarks' / ('academy_' + name + '.json')
        shutil.copyfile(source, destination)
        paths.append(destination)
    assert measurements[0]['completed_laps'] >= 1
    paths += sorted((ROOT / 'assets/characters/academy_v4').glob('*'))
    paths += [ROOT / name for name in [
        'tools/academy_character_builder.gd', 'tools/academy_face_geometry.gd',
        'tools/review_academy_faces.gd', 'tools/archive_academy_review.py',
        'scripts/driver_art.gd', 'shaders/academy_face.gdshaderinc',
        'shaders/palette_surface.gdshaderinc', 'tests/test_academy_faces.gd',
        'shaders/gpu_motion.glsl', 'tests/test_gpu_motion.gd',
        'tests/test_portrait_assets.gd', 'tests/test_gpu_skin.gd',
        'docs/character-lookdev-v2/canonical-swinka.webp',
        'docs/character-lookdev-v2/canonical-zabol.webp']]
    write_json(FOLDER / 'ASSET_MANIFEST.json', {
        'recorded_utc': datetime.now(timezone.utc).isoformat(),
        'source': 'Original local authored 3D geometry based on the retained Academia Oli portraits.',
        'capture_method': 'Unmodified native Godot output; copied byte for byte.',
        'likeness_status': 'Visual comparison provided for user assessment; tests do not certify likeness.',
        'files': [{'path': p.relative_to(ROOT).as_posix(), 'bytes': p.stat().st_size,
                   'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths],
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
    print('ACADEMY_ARCHIVE', len(paths), 'hashed files;', len(PORTRAITS) + len(GAME), 'native renders')


if __name__ == '__main__':
    archive()
