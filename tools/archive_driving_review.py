"""Archive unedited fullscreen evidence, physics checks and actual render timings."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
OUT = ROOT / 'docs/driving-foundation'
CHECKS = {
    'driving_test_handling.log': 'HANDLING_TEST PASS',
    'driving_test_driving_foundation.log': 'DRIVING_FOUNDATION_TEST PASS',
    'driving_test_rules.log': 'RULE_TEST PASS',
    'driving_test_living.log': 'LIVING_TEST PASS',
    'driving_test_environment.log': 'ENVIRONMENT_TEST PASS',
    'driving_test_world_collisions.log': 'WORLD_COLLISION_TEST PASS',
    'driving_test_session.log': 'SESSION_TEST PASS',
    'driving_test_vehicle_physics.log': 'VEHICLE_PHYSICS_TEST PASS',
    'driving_test_offroad_physics.log': 'OFFROAD_PHYSICS_TEST PASS',
    'driving_test_art.log': 'ART_TEST PASS',
    'driving_race_final.log': 'RACE_TEST PASS',
    'driving_native_final.log': 'DRIVING_NATIVE_REVIEW PASS',
    'driving_gpu_motion.log': 'GPU_MOTION_TEST PASS',
    'driving_circuit_benchmark.log': 'ART_REVIEW',
    'driving_four_benchmark.log': 'ART_REVIEW',
}


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n',
                    encoding='utf-8', newline='\n')


def copy(relative, name=None):
    source = BUILD / relative
    destination = OUT / (name or source.name)
    shutil.copyfile(source, destination)
    assert source.read_bytes() == destination.read_bytes(), relative
    return destination


def archive():
    OUT.mkdir(parents=True, exist_ok=True)
    logs = {}
    for name, marker in CHECKS.items():
        content = (BUILD/name).read_text(encoding='utf-8')
        assert marker in content and not re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)', content), name
        logs[name] = content
    finishes = re.findall(r'RACE_TEST car=(\d+) lap=3 time=([\d.]+)', logs['driving_race_final.log'])
    assert {int(slot) for slot, time in finishes} == set(range(6))
    write_json(OUT/'TEST_LOGS.json', logs)
    for name in ['headless_results', 'native_results']:
        path = copy('driving-review/'+name+'.json')
        assert json.loads(path.read_text())['failures'] == 0
    copy('collisions/offroad_results.json')
    copy('collisions/physics_results.json')
    copy('scenery-contacts/results.json', 'world_collision_results.json')
    images = []
    for name in ['camera_wall', 'camera_reverse', 'driving_hud', 'impact_hud',
                 'settings_panel', 'four_views', 'main_menu']:
        path = copy('driving-review/forward_plus_'+name+'.png', name+'.png')
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        images.append({'path': path.relative_to(ROOT).as_posix(),
                       'size': list(struct.unpack('>II', data[16:24]))})
    benchmarks = {}
    for name in ['baseline_balanced', 'balanced_release', 'performance_lod',
                 'performance_circuit', 'four_performance']:
        path = copy('driving-review/'+name+'.json')
        data = json.loads(path.read_text())
        assert data['renderer'] == 'forward_plus'
        assert data['instance_layout_valid'] and data['world_instance_layout_valid']
        assert data['root_camera_active'] is False
        benchmarks[name] = data
    assert benchmarks['performance_circuit']['completed_laps'] >= 1
    copy('driving-review/performance_circuit.png')
    copy('driving-review/four_performance.png')
    mobile = json.loads((BUILD/'art-review/single_mobile_performance.json').read_text())
    write_json(OUT/'EXPERIMENTS.json', {
        'mobile': mobile,
        'mobile_log': (BUILD/'driving_mobile_benchmark.log').read_text(encoding='utf-8'),
        'notes': ['Mobile was not adopted: slower than Forward+ and stalled at shutdown; its verified owned process was stopped.',
                  'The mobile run requested FSR but the engine warned that it was unavailable. That raw field is not proof of active FSR.',
                  'The subsequent overlapping shadow benchmark was discarded. Published final timing runs were sequential.',
                  'The final benchmark harness frees the scene and GPU pose resources before exiting.']})
    audio = json.loads((ROOT/'assets/audio/driving/MANIFEST.json').read_text())
    for item in audio['files']:
        path = ROOT/item['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256']
        assert 0 < item['rms'] < item['peak'] <= .92
        with wave.open(str(path), 'rb') as stream:
            assert stream.getnchannels() == 1 and stream.getframerate() == 22050
    paths = set(OUT.iterdir()) - {OUT/'ASSET_MANIFEST.json'}
    names = ['README.md', 'docs/PROVENANCE.md', 'project.godot', 'Run.cmd', 'Run-light.cmd',
             'tools/benchmark_art.gd', 'tools/build_driving_audio.py', 'tools/archive_driving_review.py',
             'tools/review_driving_foundation.gd', 'shaders/ground_shadow.gdshader',
             'shaders/gpu_motion.glsl', 'shaders/gpu_motion.gdshaderinc']
    paths.update(ROOT/name for name in names)
    paths.update((ROOT/'scripts').glob('*.gd'))
    paths.update((ROOT/'tests').glob('*.gd'))
    paths.update((ROOT/'assets/audio/driving').iterdir())
    paths.update((ROOT/'assets/fairytale').glob('*.res'))
    paths.update((ROOT/'assets/tea_bend').glob('*.res'))
    for path in list(paths):
        uid = Path(str(path)+'.uid')
        if uid.exists(): paths.add(uid)
    entries = []
    for path in sorted(paths):
        data = path.read_bytes()
        entries.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data),
                        'sha256': hashlib.sha256(data).hexdigest()})
    write_json(OUT/'ASSET_MANIFEST.json', {'date': '2026-11-18', 'engine': 'Godot 4.7.2 ed1daf0bf',
        'capture_method': 'Native fullscreen captures, copied byte for byte without image editing.',
        'log_method': 'Original log text stored in JSON with newline normalization.',
        'race_finish_times': {slot: float(time) for slot, time in finishes},
        'images': images, 'files': entries})
    print('DRIVING_ARCHIVE PASS:', len(entries), 'hashes;', len(images), 'native QA images')


if __name__ == '__main__':
    archive()
