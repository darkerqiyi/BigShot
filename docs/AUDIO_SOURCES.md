# Audio Sources and License Record

This file is the single provenance record for audio used by the BigShot prototype.

## Current assets

All current sound effects and both looping music tracks are original procedural assets generated at runtime by `scripts/audio/procedural_sfx.gd`. The source repository contains no imported WAV, OGG, MP3, commercial-game extraction, or third-party sample pack.

- Sound effects: deterministic mono 16-bit waveforms at 22,050 Hz, assembled from project-authored oscillators, envelopes, harmonics, and synthetic noise.
- Level and Boss music: deterministic mono 16-bit looping waveforms at 11,025 Hz, assembled from project-authored note patterns and synthesis code.
- Ownership/status: original project-authored prototype assets; usable within this project without third-party attribution.
- Quality status: production-structured original prototypes. They are intentionally replaceable by mastered recordings without changing gameplay events.

## Naming and future import rule

Future files must live under `assets/audio/<music|sfx>/<family>/`, use lowercase snake_case names, and add a row below before being committed.

| File | Source/author | License | Changes | Status |
|---|---|---|---|---|
| Runtime-generated catalog in `procedural_sfx.gd` | BigShot project | Original project work | Deterministic procedural synthesis | Active prototype |

Do not add audio whose author, source URL, or license cannot be verified. Do not extract or imitate identifiable recordings from commercial games.
