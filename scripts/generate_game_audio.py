#!/usr/bin/env python3
"""Generate original, license-free music and sound effects for the demo.

Requires Python 3, NumPy, and FFmpeg. The synthesis is intentionally gentle:
soft pentatonic motifs, breathy pads, woodland ambience, and restrained cues.
"""

from __future__ import annotations

import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets/audio"
SFX_DIR = AUDIO / "sfx"
MUSIC_DIR = AUDIO / "music"
AMBIENCE_DIR = AUDIO / "ambience"
SAMPLE_RATE = 24_000
RNG = np.random.default_rng(739251)


def midi(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def envelope(length: int, attack: float = 0.01, release: float = 0.12) -> np.ndarray:
    if length <= 0:
        return np.zeros(0, dtype=np.float32)
    t = np.arange(length, dtype=np.float32) / SAMPLE_RATE
    duration = length / SAMPLE_RATE
    attack_env = np.clip(t / max(attack, 0.001), 0.0, 1.0)
    release_env = np.clip((duration - t) / max(release, 0.001), 0.0, 1.0)
    return np.minimum(attack_env, release_env).astype(np.float32)


def tone_burst(
    frequency: float,
    duration: float,
    amplitude: float = 0.2,
    attack: float = 0.006,
    release: float = 0.15,
    harmonics: tuple[float, ...] = (1.0, 0.25, 0.08),
    decay: float = 0.0,
    vibrato: float = 0.0,
) -> np.ndarray:
    count = max(1, round(duration * SAMPLE_RATE))
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    env = envelope(count, attack, release)
    phase = 2.0 * np.pi * frequency * t
    if vibrato:
        phase += (vibrato / 5.2) * np.sin(2.0 * np.pi * 5.2 * t)
    signal = np.zeros(count, dtype=np.float32)
    for harmonic, weight in enumerate(harmonics, start=1):
        signal += np.sin(phase * harmonic) * weight
    if decay:
        env *= np.exp(-t * decay).astype(np.float32)
    return signal * env * amplitude


def pluck(frequency: float, duration: float, amplitude: float = 0.13) -> np.ndarray:
    count = max(1, round(duration * SAMPLE_RATE))
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    wave_data = np.zeros(count, dtype=np.float32)
    for harmonic, weight in enumerate((1.0, 0.45, 0.25, 0.12, 0.055, 0.025), start=1):
        detune = 1.0 + (harmonic % 3 - 1) * 0.0008
        wave_data += weight * np.sin(2.0 * np.pi * frequency * harmonic * detune * t)
    shape = np.exp(-t * (3.8 + min(frequency / 240.0, 2.2)))
    shape *= np.clip(t / 0.005, 0.0, 1.0)
    return (wave_data * shape * amplitude).astype(np.float32)


def flute(frequency: float, duration: float, amplitude: float = 0.075) -> np.ndarray:
    count = max(1, round(duration * SAMPLE_RATE))
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    phase = 2.0 * np.pi * frequency * t + 0.34 * np.sin(2.0 * np.pi * 5.0 * t)
    signal = np.sin(phase) + 0.18 * np.sin(phase * 2.0) + 0.055 * np.sin(phase * 3.0)
    env = envelope(count, 0.11, min(0.42, duration * 0.55))
    return (signal * env * amplitude).astype(np.float32)


def pad(frequency: float, duration: float, amplitude: float = 0.025) -> np.ndarray:
    count = max(1, round(duration * SAMPLE_RATE))
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    slow_phase = 2.0 * np.pi * frequency * t
    wave_data = np.sin(slow_phase)
    wave_data += 0.36 * np.sin(slow_phase * 1.003 + 0.18)
    wave_data += 0.16 * np.sin(slow_phase * 2.0)
    breath = 0.92 + 0.08 * np.sin(2.0 * np.pi * 0.17 * t + frequency)
    env = envelope(count, 0.62, 0.78)
    return (wave_data * breath * env * amplitude).astype(np.float32)


def band_noise(duration: float, low: float, high: float, seed: int | None = None) -> np.ndarray:
    count = max(2, round(duration * SAMPLE_RATE))
    rng = np.random.default_rng(seed) if seed is not None else RNG
    noise = rng.normal(0.0, 1.0, count).astype(np.float32)
    spectrum = np.fft.rfft(noise)
    frequencies = np.fft.rfftfreq(count, 1.0 / SAMPLE_RATE)
    low_shape = 1.0 / np.sqrt(1.0 + (max(low, 1.0) / np.maximum(frequencies, 1.0)) ** 8)
    high_shape = 1.0 / np.sqrt(1.0 + (frequencies / max(high, 1.0)) ** 8)
    filtered = np.fft.irfft(spectrum * low_shape * high_shape, n=count).astype(np.float32)
    filtered /= max(float(np.sqrt(np.mean(filtered * filtered))), 1e-6)
    return filtered


def add_mono(target: np.ndarray, signal: np.ndarray, start: float, gain: float = 1.0, pan: float = 0.0) -> None:
    offset = round(start * SAMPLE_RATE)
    if offset >= len(target) or offset + len(signal) <= 0:
        return
    source_start = max(0, -offset)
    dest_start = max(0, offset)
    length = min(len(signal) - source_start, len(target) - dest_start)
    if length <= 0:
        return
    p = float(np.clip(pan, -1.0, 1.0))
    left_gain = math.sqrt((1.0 - p) * 0.5)
    right_gain = math.sqrt((1.0 + p) * 0.5)
    segment = signal[source_start : source_start + length] * gain
    target[dest_start : dest_start + length, 0] += segment * left_gain
    target[dest_start : dest_start + length, 1] += segment * right_gain


def mix_signal(target: np.ndarray, signal: np.ndarray, start: int = 0) -> None:
    if start >= len(target) or start + len(signal) <= 0:
        return
    source_start = max(0, -start)
    dest_start = max(0, start)
    length = min(len(signal) - source_start, len(target) - dest_start)
    if length > 0:
        target[dest_start : dest_start + length] += signal[source_start : source_start + length]


def soften_loop(track: np.ndarray, crossfade_seconds: float = 0.8) -> np.ndarray:
    length = min(round(crossfade_seconds * SAMPLE_RATE), len(track) // 4)
    if length <= 1:
        return track
    fade = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
    blended = track[-length:] * (1.0 - fade) + track[:length] * fade
    return np.concatenate((track[length:-length], blended), axis=0)


def finish_loop(track: np.ndarray, peak: float = 0.68) -> np.ndarray:
    track = soften_loop(track)
    current = float(np.max(np.abs(track)))
    if current > peak:
        track *= peak / current
    return track


def write_wav(path: Path, audio: np.ndarray, sample_rate: int = SAMPLE_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(audio, -0.98, 0.98)
    pcm = (clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def write_ogg(path: Path, audio: np.ndarray) -> None:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("FFmpeg es necesario para comprimir música/ambiente a OGG.")
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gato-audio-") as temp_dir:
        wav_path = Path(temp_dir) / "source.wav"
        write_wav(wav_path, audio)
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(path)],
            check=True,
        )


def render_music(kind: str, bpm: float, seed: int) -> np.ndarray:
    beat = 60.0 / bpm
    bar = beat * 4.0
    duration = bar * 16.0
    track = np.zeros((round(duration * SAMPLE_RATE), 2), dtype=np.float32)
    rng = np.random.default_rng(seed)
    chord_roots = [45, 41, 48, 43]  # A minor, F major, C major, G major
    chord_intervals = [(0, 7, 12, 15, 19), (0, 7, 12, 16, 19), (0, 7, 12, 16, 19), (0, 7, 12, 16, 19)]
    pentatonic = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79]
    if kind == "title":
        melody_pattern = [0, 2, 4, 3, 1, 2, 4, 6, 4, 3, 2, 1, 0, 2, 3, 5]
        note_offsets = [0.0, 1.0, 2.5, 3.0]
    else:
        melody_pattern = [0, 2, 3, 4, 2, 1, 3, 5, 4, 2, 1, 3, 0, 2, 4, 6]
        note_offsets = [0.15, 1.5, 2.85]
    for bar_index in range(16):
        chord_index = bar_index % len(chord_roots)
        start = bar_index * bar
        root = chord_roots[chord_index]
        intervals = chord_intervals[chord_index]
        for voice_index, interval in enumerate(intervals):
            note = midi(root + interval)
            voice = pad(note, bar * 1.15, 0.016 if voice_index < 3 else 0.010)
            add_mono(track, voice, start, gain=1.0, pan=(-0.28 if voice_index % 2 else 0.28))
        # A warm low fifth moves slowly beneath the melody.
        bass = pad(midi(root - 12), bar * 1.05, 0.025)
        add_mono(track, bass, start, gain=1.0, pan=0.0)
        for beat_index, offset in enumerate(note_offsets):
            pattern_index = (bar_index * len(note_offsets) + beat_index + (2 if chord_index == 1 else 0)) % len(melody_pattern)
            note_number = pentatonic[melody_pattern[pattern_index]]
            if kind == "forest" and bar_index % 4 == 3 and beat_index == len(note_offsets) - 1:
                continue
            at = start + offset * beat
            duration_note = 0.48 + 0.2 * ((bar_index + beat_index) % 3)
            if (bar_index + beat_index) % 3 == 0:
                voice = flute(midi(note_number), duration_note, 0.053 if kind == "title" else 0.042)
                add_mono(track, voice, at, pan=float(rng.uniform(-0.24, 0.24)))
            else:
                voice = pluck(midi(note_number), duration_note, 0.082 if kind == "title" else 0.064)
                add_mono(track, voice, at, pan=(-0.42 if (bar_index + beat_index) % 2 else 0.42))
        # Very occasional soft bells add a little storybook sparkle.
        if bar_index in [3, 7, 11, 15]:
            bell = tone_burst(midi(84 + (bar_index % 2) * 2), 1.8, 0.045, 0.006, 1.45, (1.0, 0.42, 0.19, 0.07), 1.65)
            add_mono(track, bell, start + bar * 0.52, pan=0.58 if bar_index % 2 else -0.58)
    # Two quiet delays give the plucked notes a soft wooden-room tail.
    for delay_s, gain in [(0.23, 0.15), (0.41, 0.075)]:
        delay = round(delay_s * SAMPLE_RATE)
        track[delay:] += track[:-delay] * gain
    return finish_loop(track, 0.58 if kind == "forest" else 0.55)


def render_forest_ambience(seed: int = 3177) -> np.ndarray:
    duration = 36.0
    count = round(duration * SAMPLE_RATE)
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    wind = band_noise(duration, 110, 1100, seed=seed)
    leaves = band_noise(duration, 900, 5200, seed=seed + 1)
    track = np.zeros((count, 2), dtype=np.float32)
    wind_gain = 0.028 * (0.76 + 0.24 * np.sin(2.0 * np.pi * t / duration * 3.0 + 0.8))
    leaf_gain = 0.012 * (0.65 + 0.35 * np.sin(2.0 * np.pi * t / duration * 5.0 + 1.7))
    base = wind * wind_gain + leaves * leaf_gain
    track[:, 0] = base * 0.88
    track[:, 1] = base * 0.82
    rng = np.random.default_rng(seed + 2)
    for _ in range(19):
        start = float(rng.uniform(1.2, duration - 1.7))
        chirp_duration = float(rng.uniform(0.18, 0.46))
        samples = round(chirp_duration * SAMPLE_RATE)
        local_t = np.arange(samples, dtype=np.float32) / SAMPLE_RATE
        f0 = float(rng.uniform(2050, 3300))
        f1 = f0 * float(rng.uniform(1.15, 1.62))
        phase = 2.0 * np.pi * (f0 * local_t + (f1 - f0) * local_t * local_t / (2.0 * chirp_duration))
        call = (np.sin(phase) + 0.24 * np.sin(phase * 2.01)) * envelope(samples, 0.012, chirp_duration * 0.55)
        add_mono(track, call.astype(np.float32), start, gain=float(rng.uniform(0.025, 0.055)), pan=float(rng.uniform(-0.8, 0.8)))
    return finish_loop(track, 0.24)


def render_stream_ambience(seed: int, waterfall: bool = False) -> np.ndarray:
    duration = 9.0 if not waterfall else 12.0
    count = round(duration * SAMPLE_RATE)
    low = band_noise(duration, 120, 950 if not waterfall else 1800, seed=seed)
    high = band_noise(duration, 950, 7800, seed=seed + 1)
    t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
    if waterfall:
        signal = low * 0.038 + high * (0.016 + 0.004 * np.sin(2.0 * np.pi * t / duration * 2.0))
    else:
        ripple = 0.76 + 0.18 * np.sin(2.0 * np.pi * 0.34 * t) + 0.06 * np.sin(2.0 * np.pi * 1.4 * t)
        signal = (low * 0.027 + high * 0.014) * ripple
        stereo = np.column_stack((signal * 0.93, signal * 0.9)).astype(np.float32)
        for index in range(8):
            start = 0.42 + index * 1.08
            drop = tone_burst(float(2100 + 140 * (index % 4)), 0.19, 0.018, 0.002, 0.16, (1.0, 0.28), 8.0)
            add_mono(stereo, drop, start, gain=0.7, pan=0.0)
        return finish_loop(stereo, 0.22)
    stereo = np.column_stack((signal * 0.93, signal * 0.9)).astype(np.float32)
    return finish_loop(stereo, 0.22)


def noise_hit(duration: float, low: float, high: float, release: float = 0.16, seed: int | None = None) -> np.ndarray:
    noise = band_noise(duration, low, high, seed=seed)
    env = envelope(len(noise), 0.002, release)
    return noise * env


def bell_chord(notes: tuple[int, ...], duration: float = 1.5, amplitude: float = 0.1, fall: bool = False) -> np.ndarray:
    count = round(duration * SAMPLE_RATE)
    out = np.zeros(count, dtype=np.float32)
    note_list = tuple(reversed(notes)) if fall else notes
    for index, note in enumerate(note_list):
        event = tone_burst(midi(note), duration * (0.75 if index else 1.0), amplitude / max(1, len(note_list)), 0.004, duration * 0.8, (1.0, 0.48, 0.28, 0.11, 0.045), 2.0)
        start = round(index * 0.045 * SAMPLE_RATE)
        length = min(len(event), count - start)
        out[start : start + length] += event[:length]
    return out


def render_sfx(name: str, variant: int = 0) -> np.ndarray:
    rng = np.random.default_rng(9881 + sum(ord(char) for char in name) * 7 + variant)
    if name == "step_grass":
        duration = 0.20
        body = noise_hit(duration, 90 + variant * 8, 680, 0.12, int(rng.integers(0, 1_000_000))) * 0.62
        rustle = noise_hit(duration, 1000, 6000, 0.1, int(rng.integers(0, 1_000_000))) * 0.18
        out = body + rustle
        mix_signal(out, tone_burst(95 + variant * 7, 0.13, 0.10, 0.002, 0.1, (1.0, 0.4), 15.0))
    elif name == "step_water":
        duration = 0.38
        out = noise_hit(duration, 250, 5200, 0.21, int(rng.integers(0, 1_000_000))) * 0.34
        mix_signal(out, tone_burst(760 + variant * 90, 0.19, 0.13, 0.002, 0.17, (1.0, 0.3, 0.12), 10.0))
        mix_signal(out, tone_burst(1330 + variant * 70, 0.13, 0.055, 0.001, 0.1, (1.0, 0.35), 14.0))
    elif name == "staff_swing" or name == "dodge":
        duration = 0.34 if name == "dodge" else 0.29
        whoosh = noise_hit(duration, 280, 6200, duration * 0.6, int(rng.integers(0, 1_000_000)))
        t = np.arange(len(whoosh), dtype=np.float32) / SAMPLE_RATE
        shape = np.sin(np.pi * np.clip(t / duration, 0.0, 1.0)) ** (1.25 if name == "dodge" else 1.8)
        out = whoosh * shape * (0.26 if name == "dodge" else 0.20)
        if name == "dodge":
            mix_signal(out, tone_burst(150, 0.19, 0.06, 0.003, 0.16, (1.0, 0.4), 11.0))
    elif name in ["staff_hit", "bandit_attack", "bandit_hit", "player_hurt"]:
        duration = 0.48 if name == "bandit_attack" else 0.31
        out = noise_hit(duration, 75, 1300 if name != "bandit_hit" else 2500, duration * 0.55, int(rng.integers(0, 1_000_000))) * 0.4
        mix_signal(out, tone_burst(88 if name == "player_hurt" else 118 + variant * 13, duration * 0.8, 0.24, 0.003, duration * 0.65, (1.0, 0.5, 0.18), 12.0))
        if name in ["bandit_hit", "staff_hit"]:
            mix_signal(out, tone_burst(310 + variant * 35, 0.14, 0.11, 0.001, 0.1, (1.0, 0.24), 13.0))
    elif name == "guard":
        duration = 0.76
        out = np.zeros(round(duration * SAMPLE_RATE), dtype=np.float32)
        for offset, note in [(0.0, 74), (0.07, 81), (0.15, 86), (0.23, 93)]:
            tone = tone_burst(midi(note), 0.62, 0.09, 0.035, 0.48, (1.0, 0.43, 0.2), 2.4, vibrato=3.0)
            start = round(offset * SAMPLE_RATE)
            mix_signal(out, tone, start)
        shimmer = noise_hit(0.42, 2500, 8000, 0.34, int(rng.integers(0, 1_000_000)))
        out[: len(shimmer)] += shimmer * 0.07
    elif name == "arrow_release":
        duration = 0.40
        count = round(duration * SAMPLE_RATE)
        t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
        tuning = 1.0 + variant * 0.006
        string_body = np.zeros(count, dtype=np.float32)
        for frequency, weight, decay in [(152, 0.52, 15.0), (319, 0.29, 20.0), (487, 0.17, 25.0), (835, 0.08, 31.0)]:
            detune = 1.0 + (variant - 1) * 0.003 + frequency * 0.000002
            string_body += np.sin(2.0 * np.pi * frequency * tuning * detune * t) * weight * np.exp(-t * decay)
        string_body *= np.clip(t / 0.0015, 0.0, 1.0)
        out = np.zeros(count, dtype=np.float32)
        snap = noise_hit(0.026, 1400, 9200, 0.024, int(rng.integers(0, 1_000_000))) * 0.38
        wood_click = noise_hit(0.055, 110, 1150, 0.047, int(rng.integers(0, 1_000_000))) * 0.25
        mix_signal(out, snap, round(0.001 * SAMPLE_RATE))
        mix_signal(out, wood_click, round(0.004 * SAMPLE_RATE))
        mix_signal(out, string_body * 0.34, round(0.003 * SAMPLE_RATE))
        arrow_air = band_noise(duration - 0.025, 850, 7800, seed=int(rng.integers(0, 1_000_000)))
        air_t = np.arange(len(arrow_air), dtype=np.float32) / SAMPLE_RATE
        air_env = np.exp(-air_t * 9.5) * np.clip(air_t / 0.012, 0.0, 1.0)
        mix_signal(out, arrow_air * air_env * 0.055, round(0.025 * SAMPLE_RATE))
    elif name == "arrow_impact":
        out = noise_hit(0.34, 120, 3200, 0.2, int(rng.integers(0, 1_000_000))) * 0.34
        mix_signal(out, tone_burst(164 + variant * 24, 0.26, 0.16, 0.001, 0.2, (1.0, 0.42, 0.18), 12.0))
        mix_signal(out, tone_burst(1040, 0.08, 0.045, 0.001, 0.06, (1.0, 0.3), 18.0))
    elif name == "pickup":
        out = bell_chord((76, 81, 88), 0.95, 0.23)
    elif name == "sigil_on":
        out = bell_chord((62 + variant, 69 + variant, 74 + variant, 81 + variant), 1.75, 0.28)
    elif name == "sigil_wrong":
        out = bell_chord((64, 67, 72), 1.05, 0.25, fall=True)
    elif name == "shrine_open":
        out = bell_chord((57, 64, 69, 76), 3.4, 0.36)
        count = round(1.9 * SAMPLE_RATE)
        swell = noise_hit(1.9, 140, 2700, 1.3, int(rng.integers(0, 1_000_000)))
        start = round(0.35 * SAMPLE_RATE)
        out[start : start + count] += swell * 0.11
        for offset, note in [(0.5, 81), (1.0, 84), (1.55, 88)]:
            chime = tone_burst(midi(note), 1.5, 0.055, 0.01, 1.25, (1.0, 0.42, 0.2), 1.8)
            at = round(offset * SAMPLE_RATE)
            out[at : at + len(chime)] += chime
    elif name == "nimbo_call":
        duration = 0.82
        count = round(duration * SAMPLE_RATE)
        t = np.arange(count, dtype=np.float32) / SAMPLE_RATE
        f0 = 480.0 + 240.0 * np.sin(np.pi * np.clip(t / duration, 0.0, 1.0))
        phase = 2.0 * np.pi * np.cumsum(f0) / SAMPLE_RATE
        mew = (np.sin(phase) + 0.48 * np.sin(phase * 2.0) + 0.2 * np.sin(phase * 3.0)) * envelope(count, 0.055, 0.31)
        mew *= 0.13 * (0.8 + 0.2 * np.sin(2.0 * np.pi * 11.0 * t))
        bell = tone_burst(1320, 0.72, 0.038, 0.08, 0.5, (1.0, 0.34, 0.16), 3.3)
        out = mew.copy()
        mix_signal(out, bell)
    elif name == "bandit_windup":
        duration = 0.66
        breath = noise_hit(duration, 140, 850, 0.32, int(rng.integers(0, 1_000_000))) * 0.16
        t = np.arange(len(breath), dtype=np.float32) / SAMPLE_RATE
        out = breath * (0.12 + 0.88 * np.clip(t / duration, 0.0, 1.0))
        mix_signal(out, tone_burst(90, 0.42, 0.07, 0.12, 0.3, (1.0, 0.25), 2.0))
    elif name == "bandit_death":
        out = noise_hit(1.25, 90, 2400, 0.8, int(rng.integers(0, 1_000_000))) * 0.26
        mix_signal(out, tone_burst(92, 1.1, 0.22, 0.01, 0.85, (1.0, 0.42, 0.15), 4.4))
        mix_signal(out, tone_burst(650, 0.75, 0.055, 0.01, 0.65, (1.0, 0.3), 4.0))
    elif name in ["ui_hover", "ui_confirm", "ui_pause", "victory", "game_over"]:
        if name == "ui_hover":
            out = tone_burst(1150, 0.12, 0.075, 0.002, 0.1, (1.0, 0.25), 15.0)
        elif name == "ui_confirm":
            out = bell_chord((79, 86), 0.48, 0.24)
        elif name == "ui_pause":
            out = bell_chord((74, 81, 86), 0.82, 0.22)
        elif name == "victory":
            out = bell_chord((69, 76, 81, 88), 2.2, 0.32)
        else:
            out = bell_chord((64, 60, 57), 1.7, 0.22, fall=True)
    else:
        raise ValueError(f"Unknown sound: {name}")
    stereo = np.column_stack((out, out * 0.92)).astype(np.float32)
    peak = float(np.max(np.abs(stereo)))
    if peak > 0.74:
        stereo *= 0.74 / peak
    return stereo


def main() -> None:
    for directory in (SFX_DIR, MUSIC_DIR, AMBIENCE_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    write_ogg(MUSIC_DIR / "title_theme.ogg", render_music("title", 78.0, 2501))
    write_ogg(MUSIC_DIR / "forest_theme.ogg", render_music("forest", 74.0, 2502))
    write_ogg(MUSIC_DIR / "sanctuary_theme.ogg", render_music("title", 68.0, 2503))
    write_ogg(AMBIENCE_DIR / "forest.ogg", render_forest_ambience())
    write_ogg(AMBIENCE_DIR / "stream.ogg", render_stream_ambience(7102))
    write_ogg(AMBIENCE_DIR / "waterfall.ogg", render_stream_ambience(7103, waterfall=True))
    sfx_names = [
        "staff_swing", "staff_hit", "dodge", "guard", "arrow_release", "arrow_impact",
        "pickup", "sigil_on", "sigil_wrong", "shrine_open", "nimbo_call", "bandit_windup",
        "bandit_attack", "bandit_hit", "bandit_death", "player_hurt", "ui_hover", "ui_confirm",
        "ui_pause", "victory", "game_over",
    ]
    for name in sfx_names:
        write_wav(SFX_DIR / f"{name}.wav", render_sfx(name))
    for variant in range(1, 4):
        write_wav(SFX_DIR / f"step_grass_{variant}.wav", render_sfx("step_grass", variant))
        write_wav(SFX_DIR / f"step_water_{variant}.wav", render_sfx("step_water", variant))
    print(f"Generated original audio in {AUDIO.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
