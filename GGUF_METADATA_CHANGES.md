# GGUF Metadata Support - Manual PR #399 Implementation

This document describes the manual application of [ComfyUI-GGUF PR #399](https://github.com/city96/ComfyUI-GGUF/pull/399) and the additional compatibility fixes required for the ComfyUI installation.

## Overview

PR #399 adds support for loading model configuration directly from GGUF file metadata, enabling ComfyUI-GGUF to properly handle newer models like LTX2 that store their configuration in the GGUF file headers rather than as separate files.

## Changes Made

### 1. ComfyUI-GGUF Repository

**Branch:** `pr399-metadata-support`
**Commit:** `fbf7419`
**Files Modified:** `loader.py`, `nodes.py`

#### loader.py Changes

1. **Added `get_gguf_metadata()` function** (lines 51-68)
   ```python
   def get_gguf_metadata(reader):
       """Extract all simple metadata fields like safetensors"""
       metadata = {}
       for field_name in reader.fields:
           try:
               field = reader.get_field(field_name)
               if len(field.types) == 1:  # Simple scalar fields only
                   if field.types[0] == gguf.GGUFValueType.STRING:
                       metadata[field_name] = str(field.parts[field.data[-1]], "utf-8")
                   elif field.types[0] == gguf.GGUFValueType.INT32:
                       metadata[field_name] = int(field.parts[field.data[-1]])
                   elif field.types[0] == gguf.GGUFValueType.F32:
                       metadata[field_name] = float(field.parts[field.data[-1]])
                   elif field.types[0] == gguf.GGUFValueType.BOOL:
                       metadata[field_name] = bool(field.parts[field.data[-1]])
           except:
               continue
       return metadata
   ```

2. **Modified `gguf_sd_loader()` return signature** (lines 158-161)
   - **Before:** Returns `state_dict` or `(state_dict, arch_str)`
   - **After:** Returns `(state_dict, metadata)` or `(state_dict, arch_str, metadata)`

   ```python
   metadata = get_gguf_metadata(reader)
   if return_arch:
       return (state_dict, arch_str, metadata)
   return (state_dict, metadata)
   ```

3. **Updated `gguf_mmproj_loader()`** (line 269)
   ```python
   # Before:
   vsd = gguf_sd_loader(target, is_text_model=True)

   # After:
   vsd, _ = gguf_sd_loader(target, is_text_model=True)
   ```

4. **Updated `gguf_clip_loader()`** (line 398)
   ```python
   # Before:
   sd, arch = gguf_sd_loader(path, return_arch=True, is_text_model=True)

   # After:
   sd, arch, metadata = gguf_sd_loader(path, return_arch=True, is_text_model=True)
   ```

#### nodes.py Changes

**Updated `UnetLoaderGGUF.load_unet()` method** (lines 168-170)
```python
# Before:
sd = gguf_sd_loader(unet_path)
model = comfy.sd.load_diffusion_model_state_dict(
    sd, model_options={"custom_operations": ops}
)

# After:
sd, metadata = gguf_sd_loader(unet_path)
model = comfy.sd.load_diffusion_model_state_dict(
    sd, model_options={"custom_operations": ops}, metadata=metadata
)
```

### 2. ComfyUI-KJNodes Repository

**Branch:** `fix-gguf-metadata-compatibility`
**Commit:** `bd0adfe`
**File Modified:** `nodes/model_optimization_nodes.py`

#### model_optimization_nodes.py Changes

**Updated GGUFLoader class** (lines 1638-1649)

The kjnodes custom node was calling `gguf_sd_loader()` directly and needed to be updated to handle the new return signature.

```python
# Before:
model_path = folder_paths.get_full_path("unet", model_name)
sd = gguf_nodes.loader.gguf_sd_loader(model_path)

if extra_model_name is not None and extra_model_name != "none":
    if not extra_model_name.endswith(".gguf"):
        raise ValueError("Extra model must also be a .gguf file")
    extra_model_full_path = folder_paths.get_full_path("unet", extra_model_name)
    extra_model = gguf_nodes.loader.gguf_sd_loader(extra_model_full_path)
    sd.update(extra_model)

model = comfy.sd.load_diffusion_model_state_dict(
    sd, model_options={"custom_operations": ops}
)

# After:
model_path = folder_paths.get_full_path("unet", model_name)
sd, metadata = gguf_nodes.loader.gguf_sd_loader(model_path)

if extra_model_name is not None and extra_model_name != "none":
    if not extra_model_name.endswith(".gguf"):
        raise ValueError("Extra model must also be a .gguf file")
    extra_model_full_path = folder_paths.get_full_path("unet", extra_model_name)
    extra_model, extra_metadata = gguf_nodes.loader.gguf_sd_loader(extra_model_full_path)
    sd.update(extra_model)
    metadata.update(extra_metadata)

model = comfy.sd.load_diffusion_model_state_dict(
    sd, model_options={"custom_operations": ops}, metadata=metadata
)
```

## Error Fixed

### Original Error
```
AttributeError: 'dict' object has no attribute 'startswith'
```

### Root Cause
The `gguf_sd_loader()` function's return signature changed from returning a single `state_dict` to returning a tuple `(state_dict, metadata)`. Code that wasn't updated to unpack this tuple would receive the tuple itself instead of just the state dict, causing type errors downstream.

### Solution
All calls to `gguf_sd_loader()` were updated to properly unpack the returned tuple and pass the metadata to `comfy.sd.load_diffusion_model_state_dict()`.

## Testing

After applying these changes:
1. Restart ComfyUI completely
2. Test loading GGUF models, especially newer models like LTX2
3. Verify that workflows using the GGUFLoader nodes work correctly

## Git Repositories

### ComfyUI-GGUF
- **Original Repository:** https://github.com/city96/ComfyUI-GGUF
- **Branch:** `pr399-metadata-support`
- **Location:** `custom_nodes/ComfyUI-GGUF/`

To push your fork (after setting up your own remote):
```bash
cd custom_nodes/ComfyUI-GGUF
git remote add myfork <your-fork-url>
git push myfork pr399-metadata-support
```

### ComfyUI-KJNodes
- **Original Repository:** https://github.com/kijai/ComfyUI-KJNodes
- **Branch:** `fix-gguf-metadata-compatibility`
- **Location:** `custom_nodes/comfyui-kjnodes/`

To push your fork (after setting up your own remote):
```bash
cd custom_nodes/comfyui-kjnodes
git remote add myfork <your-fork-url>
git push myfork fix-gguf-metadata-compatibility
```

## Impact

This change is a **breaking change** for any code that calls `gguf_sd_loader()` directly. All such code must be updated to handle the new return signature.

### Files Updated in This Installation
1. `custom_nodes/ComfyUI-GGUF/loader.py`
2. `custom_nodes/ComfyUI-GGUF/nodes.py`
3. `custom_nodes/comfyui-kjnodes/nodes/model_optimization_nodes.py`

### Potential Impact on Other Custom Nodes
If you have other custom nodes that import and use `gguf_sd_loader()` directly, they will also need to be updated following the same pattern shown above.

## Credits

- **Original PR Author:** Vantage with AI (@anshoosr)
- **PR Link:** https://github.com/city96/ComfyUI-GGUF/pull/399
- **Manual Implementation:** Claude Sonnet 4.5

## References

- [ComfyUI-GGUF PR #399](https://github.com/city96/ComfyUI-GGUF/pull/399)
- [ComfyUI-GGUF Repository](https://github.com/city96/ComfyUI-GGUF)
- [ComfyUI-KJNodes Repository](https://github.com/kijai/ComfyUI-KJNodes)
