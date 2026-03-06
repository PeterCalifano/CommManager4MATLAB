# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CommManager4MATLAB** is a pure MATLAB library providing communication management classes for interfacing with external processes via TCP and UDP sockets. Primary use cases: driving the BlenderPy/CORTO renderer for image synthesis and exchanging tensor data with PyTorchAutoForge inference servers.

## Code Organization

```
src/                        - Main source (add this to MATLAB path)
  CommManager.m             - Base class (handle); wraps tcpclient/udpport
  BlenderPyCommManager.m    - Subclass for BlenderPy renderer interface
  TensorCommManager.m       - Subclass for PyTorchAutoForge tensor exchange
  EnumCommMode.m            - TCP | UDP | UDP_TCP
  EnumCommDataType.m        - DOUBLE | SINGLE | UINT8 | UINT16 | UINT32 | UNSET
  EnumRenderingFrame.m      - TARGET_BODY | CAMERA | CUSTOM_FRAME
  images_utils/             - Image conversion utilities (Bayer, RGBA unpacking)
  utils/                    - Process management (tmux, PID detection)
  simulink/                 - Simulink block (CommManager4SLX.slx)
lib/
  yaml/                     - Community YAML library (+yaml package)
  matlab-msgpack_PeterCdev/ - msgpack serialization library
tests/                      - Test scripts (run from MATLAB)
```

## Running Tests

Tests are standalone MATLAB scripts - run directly from MATLAB:

```matlab
run('tests/testCommManager.m')
run('tests/testBlenderPyCommManager.m')
run('tests/testCommManagerUDP_TCP2BlenderPy.m')
run('tests/testUDP_TCPserver.m')
run('tests/tmux_probing.m')
```

`tests/loadTestData.m` provides shared test fixture data for other test scripts.

## Class Architecture

`CommManager` is a `handle` class wrapping MATLAB's `tcpclient` and `udpport`. All subclasses call the superclass constructor via `self@CommManager(...)`.

**Communication modes** (`EnumCommMode`):

- `TCP` - single `tcpclient` object; `ReadBuffer` reads a 4-byte length header then the payload by default, or a fixed byte count if `i64RecvTCPsize` is set
- `UDP` - single `udpport` object (not fully implemented)
- `UDP_TCP` - both objects; used by `BlenderPyCommManager` (UDP send --> Blender, TCP recv ← Blender rendered image)

**BlenderPyCommManager** adds:

- Auto server startup/shutdown via `system()` calls or tmux sessions
- YAML config read/write via `lib/yaml` for Blender camera and rendering parameters
- Image buffer decoding (RGBA --> RGB via `images_utils/`)
- `CCameraIntrinsics` integration (from external `SimulationGears_for_SpaceNav` repo)
- Default ports: TCP=30001, UDP=51000; target UDP recv=51001

**TensorCommManager** adds:

- `WriteBuffer` overload that serializes N-d arrays to the wire format expected by PyTorchAutoForge
- `bMULTI_TENSOR` flag for multi-tensor messages

## Key Patterns

### MATLAB Path Setup

All `src/` subdirectories must be on the MATLAB path before use. Add `lib/yaml` and `lib/matlab-msgpack_PeterCdev` as well.

### TCP Receive Size Modes (`i64RecvTCPsize`)

- `-1` (default): reads first 4 bytes as `uint32` message length, then reads that many bytes
- Any positive value: reads exactly that many bytes
- `-5`: "eager" mode (not yet implemented)
- `-10`: "autocompute" mode (must be set by subclass)

### Constructor Pattern

All classes use MATLAB `arguments` blocks for validated keyword arguments. Pass kwargs as name-value pairs:

```matlab
obj = CommManager("127.0.0.1", uint32(30001), 30.0, ...
    "enumCommMode", EnumCommMode.TCP, ...
    "bInitInPlace", true);
```

### Server Auto-Management (BlenderPyCommManager)

When `bAutoManageBlenderServer=true`, the class composes a shell command to start Blender in a tmux session using `ComposeCommandForBpyInTmux`. `CheckExistsTmuxSession` prompts the user interactively if a session already exists. `GetMatchingProcessPID` identifies the Blender server PID via `pgrep -a`.

## Naming Conventions

Same Hungarian-notation prefixes as the parent nav-frontend project:

| Prefix | Type |
|--------|------|
| `C` | Class |
| `Enum` | Enumeration |
| `b` | Boolean |
| `ui32` / `ui64` / `ui8` | unsigned int scalars |
| `d` | Double array |
| `char` | Character array / string |
| `i_` / `o_` | Input / output arguments |

## External Dependencies

- **SimulationGears_for_SpaceNav** - provides `CCameraIntrinsics`; required by `BlenderPyCommManager`
- **BlenderPy / CORTO** - the Blender Python server that `BlenderPyCommManager` connects to
- **PyTorchAutoForge** - the Python TCP server that `TensorCommManager` connects to; default port 55556
- `lib/yaml` and `lib/matlab-msgpack_PeterCdev` are bundled in this repo
