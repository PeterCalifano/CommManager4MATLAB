# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running Tests

```matlab
% Add required paths first
addpath(genpath('src'));
addpath(genpath('lib'));

% Run offline unit tests (no server required)
results = runtests('tests/TestTensorSerialization.m');
disp(results)

% Run TCP integration tests (spawns mock_tcp_server.py automatically)
results = runtests('tests/TestTCPCommManager.m');
disp(results)

% Run all automated tests
results = runtests('tests', 'Name', 'Test*');
disp(results)
```

The legacy scripts (`testCommManagerUDP_TCP2BlenderPy.m`, `testBlenderPyCommManager.m`) are **integration scripts**, not unit tests. They require live external processes (Blender, PyTorchAutoForge server) and cannot be run standalone.

## Architecture

```
CommManager  (handle)          base class: wraps tcpclient + udpport
├── TensorCommManager          N-dim array exchange with PyTorchAutoForge (port 55556)
└── BlenderPyCommManager       Blender Python renderer interface (ports [30001, 51000])
```

`CommManager` is a `handle` class — all methods modify `self` in-place. Returning `self` from methods is redundant but present throughout the code.

### TCP framing

`WriteBuffer(buf, bAddDataSize=true)` prepends a 4-byte little-endian `uint32` payload length before sending.

`ReadBuffer()` default mode (`i64RecvTCPsize == -1`) reads a 4-byte `uint32` header first, then reads exactly that many bytes.

`TensorCommManager` adds a second **inner** length prefix inside the payload:

```
Wire format (single tensor):
[4B outer_len][4B inner_len][4B ndims][ndims×4B shape_i][numel×4B single_data]
```

`Bytes2TensorArray` takes `inner_len` as its first argument and the buffer *after* the inner prefix as its second. This double-framing is an artefact of the current implementation.

### Serialization helpers (static, offline)

All live in `TensorCommManager`:

| Method | Direction | Network |
|---|---|---|
| `TensorArray2Bytes(A)` | double/single → `uint8` | No |
| `Bytes2TensorArray(len, buf)` | `uint8` → double | No |
| `MultiTensor2Bytes(cellArrays)` | cell of arrays → `uint8` | No |
| `Bytes2MultiTensor(buf)` | `uint8` → cell of arrays | No |

**Known bug**: `Bytes2MultiTensor` has `{isscalar}` in its `arguments` block, which rejects any buffer longer than 1 byte. The `TestTensorSerialization` test for this function is expected to fail until the bug is fixed.

### Dependencies

- `lib/matlab-msgpack_PeterCdev/` — `dumpmsgpack` / `parsemsgpack` for struct serialization
- community `yaml` library — required by `parseYamlConfig_` / `serializeYamlConfig_`
- `BlenderPyCommManager` additionally requires `CCameraIntrinsics` from `SimulationGears_for_SpaceNav`

## Test infrastructure

`tests/mock_tcp_server.py` — minimal Python 3 TCP echo server (stdlib only).
Protocol: `[4B LE uint32 length][payload]` → echoes back verbatim.
Default port: `55556`. Accepts connections sequentially, self-exits after 10 s idle.

`TestTCPCommManager` starts and stops it automatically via `system()` on Linux/macOS.
Requires Python 3 on `PATH` (`python3`).
