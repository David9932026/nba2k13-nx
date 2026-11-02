/**
 * @file        ppc/func.h
 * @brief       Recompiled PPC function signature, mapping table, and definition macros
 *
 * @copyright   Copyright (c) 2026 Tom Clay <tomc@tctechstuff.com>
 *              All rights reserved.
 *
 * @license     BSD 3-Clause License
 *              See LICENSE file in the project root for full license text.
 *
 * @remarks     Split out of rex/ppc/context.h so callers that only need the
 *              PPCFunc type do not pull in PPCContext and its SIMD headers.
 */

#pragma once

#include <cstddef>
#include <cstdint>

//=============================================================================
// PPCFunc Type Definition
//=============================================================================
// Function signature for recompiled PPC functions.
// All recompiled functions take a context reference and memory base pointer.

// Forward declaration of the PPC execution context
struct PPCContext;

// Function signature for recompiled PPC functions
using PPCFunc = void(PPCContext& ctx, uint8_t* base);

namespace rex::runtime {
PPCFunc* ResolveIndirectFunction(uint32_t guest_address);
// Validates a host function pointer read straight out of the guest dispatch
// table. The table lives in guest memory, so a title that writes past the end of
// one of its own buffers can put garbage into a slot; calling that garbage is a
// host-level crash with no diagnostic. Returns nullptr in that case so the
// caller falls back to the authoritative dispatcher lookup instead.
PPCFunc* ValidateIndirectFunc(PPCFunc* fn);
}  // namespace rex::runtime

//=============================================================================
// PPC Function Macros
//=============================================================================

#define REX_JOIN(x, y) x##y
#define REX_XSTRINGIFY(x) #x
#define REX_STRINGIFY(x) REX_XSTRINGIFY(x)
// REX_FUNC is the bare signature; the declaring site supplies linkage, either
// by writing extern "C" itself or by using REX_EXTERN.
#define REX_FUNC(x) void x([[maybe_unused]] PPCContext& __restrict ctx, uint8_t* base)
#define REX_EXTERN(x) extern "C" REX_FUNC(x)

//=============================================================================
// Function Mapping
//=============================================================================

struct PPCFuncMapping {
  size_t guest;
  PPCFunc* host;
};

extern PPCFuncMapping PPCFuncMappings[];
