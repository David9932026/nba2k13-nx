/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2022 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 *
 * @modified    Tom Clay, 2026 - Adapted for ReXGlue runtime
 */

// Disable warnings about unused parameters for kernel functions
#pragma GCC diagnostic ignored "-Wunused-parameter"

#include <rex/dbg.h>
#include <rex/kernel/xboxkrnl/private.h>
#include <rex/logging.h>

#include <fmt/format.h>
#include <string>
#include <rex/hook.h>
#include <rex/types.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xexception.h>
#include <rex/system/xthread.h>
#include <rex/system/xtypes.h>

namespace rex::kernel::xboxkrnl {
using namespace rex::system;

// PATCH(cola): 把 guest 侧 DbgBreakPoint / RtlRaiseException 的静默自杀改成「记日志 + 继续」。
// 之前它们直接 rex::debug::Break()，宿主进程以 0x80000003 静默崩掉，日志里一个字都没有，
// 看起来像「跑着跑着就没了」。现在把 guest 异常码和调用栈打出来，进程不再死。
#if REX_PLATFORM_WIN32
extern "C" __declspec(dllimport) unsigned short __stdcall RtlCaptureStackBackTrace(
    unsigned long FramesToSkip, unsigned long FramesToCapture, void** BackTrace,
    unsigned long* BackTraceHash);
extern "C" __declspec(dllimport) void* __stdcall GetModuleHandleW(const wchar_t* name);
#endif

static void LogGuestTrapStack(const char* tag) {
#if REX_PLATFORM_WIN32
  void* frames[20] = {};
  uintptr_t base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
  unsigned short n = RtlCaptureStackBackTrace(1, 20, frames, nullptr);
  std::string acc;
  for (unsigned short i = 0; i < n; ++i) {
    uintptr_t rva = reinterpret_cast<uintptr_t>(frames[i]) - base;
    acc += fmt::format(" {:X}", (unsigned long long)rva);
  }
  REXKRNL_INFO("[{}STACK] <-{}", tag, acc);
#else
  (void)tag;
#endif
}

void DbgBreakPoint_entry() {
  // PATCH(cola): 游戏的内部断言会走这里。不再断死宿主进程，只记录。
  static int count = 0;
  ++count;
  if (count <= 24) {
    REXKRNL_INFO("[GUESTBREAK] #{} guest called DbgBreakPoint", count);
    LogGuestTrapStack("GUESTBREAK");
  }
}

// https://msdn.microsoft.com/en-us/library/xcb2z8hs.aspx
typedef struct {
  rex::be<uint32_t> type;
  rex::be<uint32_t> name_ptr;
  rex::be<uint32_t> thread_id;
  rex::be<uint32_t> flags;
} X_THREADNAME_INFO;
static_assert_size(X_THREADNAME_INFO, 0x10);

void HandleSetThreadName(ppc_ptr_t<X_EXCEPTION_RECORD> record) {
  // SetThreadName. FFS.
  // https://msdn.microsoft.com/en-us/library/xcb2z8hs.aspx

  // TODO(benvanik): check record->number_parameters to make sure it's a
  // correct size.
  auto thread_info = reinterpret_cast<X_THREADNAME_INFO*>(&record->exception_information[0]);

  assert_true(thread_info->type == 0x1000);

  if (!thread_info->name_ptr) {
    REXKRNL_DEBUG("SetThreadName called with null name_ptr");
    return;
  }

  // 4D5307D6 (and its demo) has a bug where it ends up passing freed memory for
  // the name, so at the point of SetThreadName it's filled with junk.

  // TODO(gibbed): cvar for thread name encoding for conversion, some games use
  // SJIS and there's no way to automatically know this.
  auto name =
      std::string(REX_KERNEL_MEMORY()->TranslateVirtual<const char*>(thread_info->name_ptr));
  std::replace_if(name.begin(), name.end(), [](auto c) { return c < 32 || c > 127; }, '?');

  object_ref<XThread> thread;
  if (thread_info->thread_id == -1) {
    // Current thread.
    thread = retain_object(XThread::GetCurrentThread());
  } else {
    // Lookup thread by ID.
    thread = REX_KERNEL_STATE()->GetThreadByID(thread_info->thread_id);
  }

  if (thread) {
    REXKRNL_DEBUG("SetThreadName({}, {})", thread->thread_id(), name);
    thread->set_name(name);
  }

  // TODO(benvanik): unwinding required here?
}

typedef struct {
  rex::be<int32_t> mdisp;
  rex::be<int32_t> pdisp;
  rex::be<int32_t> vdisp;
} x_PMD;

typedef struct {
  rex::be<uint32_t> properties;
  rex::be<uint32_t> type_ptr;
  x_PMD this_displacement;
  rex::be<int32_t> size_or_offset;
  rex::be<uint32_t> copy_function_ptr;
} x_s__CatchableType;

typedef struct {
  rex::be<int32_t> number_catchable_types;
  rex::be<uint32_t> catchable_type_ptrs[1];
} x_s__CatchableTypeArray;

typedef struct {
  rex::be<uint32_t> attributes;
  rex::be<uint32_t> unwind_ptr;
  rex::be<uint32_t> forward_compat_ptr;
  rex::be<uint32_t> catchable_type_array_ptr;
} x_s__ThrowInfo;

void HandleCppException(ppc_ptr_t<X_EXCEPTION_RECORD> record) {
  // C++ exception.
  // https://blogs.msdn.com/b/oldnewthing/archive/2010/07/30/10044061.aspx
  // http://www.drdobbs.com/visual-c-exception-handling-instrumentat/184416600
  // http://www.openrce.org/articles/full_view/21

  assert_true(record->number_parameters == 3);
  assert_true(record->exception_information[0] == 0x19930520);

  auto thrown_ptr = record->exception_information[1];
  auto thrown = REX_KERNEL_MEMORY()->TranslateVirtual(thrown_ptr);
  auto vftable_ptr = *reinterpret_cast<rex::be<uint32_t>*>(thrown);

  auto throw_info_ptr = record->exception_information[2];
  auto throw_info = REX_KERNEL_MEMORY()->TranslateVirtual<x_s__ThrowInfo*>(throw_info_ptr);
  auto catchable_types = REX_KERNEL_MEMORY()->TranslateVirtual<x_s__CatchableTypeArray*>(
      throw_info->catchable_type_array_ptr);

  rex::debug::Break();
}

void RtlRaiseException_entry(ppc_ptr_t<X_EXCEPTION_RECORD> record) {
  // PATCH(cola): 记录 guest 异常码，然后继续 —— 之前这里无条件 Break，
  // 宿主进程以 0x80000003 静默退出，看不出游戏到底抛了什么。
  static int count = 0;
  ++count;
  if (!record) {
    if (count <= 24) {
      REXKRNL_INFO("[GUESTEXC] #{} RtlRaiseException with null record", count);
    }
    return;
  }
  const u32 code = record->code;
  switch (code) {
    case 0x406D1388: {
      HandleSetThreadName(record);
      return;
    }
    case 0xE06D7363: {
      if (count <= 24) {
        REXKRNL_INFO(
            "[GUESTEXC] #{} C++ exception thrown np={} info=[0x{:08X}, 0x{:08X}, 0x{:08X}, "
            "0x{:08X}]",
            count, uint32_t(record->number_parameters),
            uint32_t(record->exception_information[0]),
            uint32_t(record->exception_information[1]),
            uint32_t(record->exception_information[2]),
            uint32_t(record->exception_information[3]));
        // 被抛对象的 vftable，能对上 PC 版类名时可以直接当线索。
        const u32 thrown_ptr = record->exception_information[1];
        if (thrown_ptr) {
          auto thrown = REX_KERNEL_MEMORY()->TranslateVirtual(thrown_ptr);
          if (thrown) {
            const u32 vftable = *reinterpret_cast<rex::be<uint32_t>*>(thrown);
            REXKRNL_INFO("[GUESTEXC] #{} thrown object 0x{:08X} vftable=0x{:08X}", count,
                         thrown_ptr, vftable);
          }
        }
        LogGuestTrapStack("GUESTEXC");
      }
      return;
    }
    default:
      break;
  }

  if (count <= 24) {
    REXKRNL_INFO("[GUESTEXC] #{} unhandled code=0x{:08X} np={} info=[0x{:08X}, 0x{:08X}, 0x{:08X}, 0x{:08X}]",
                 count, uint32_t(record->code), uint32_t(record->number_parameters),
                 uint32_t(record->exception_information[0]),
                 uint32_t(record->exception_information[1]),
                 uint32_t(record->exception_information[2]),
                 uint32_t(record->exception_information[3]));
    LogGuestTrapStack("GUESTEXC");
  }
}

void KeBugCheckEx_entry(u32 code, u32 param1, u32 param2, u32 param3, u32 param4) {
  REXKRNL_DEBUG("*** STOP: 0x{:08X} (0x{:08X}, 0x{:08X}, 0x{:08X}, 0x{:08X})", code, param1, param2,
                param3, param4);
  fflush(stdout);
  rex::debug::Break();
  assert_always();
}

void KeBugCheck_entry(u32 code) {
  KeBugCheckEx_entry(code, 0, 0, 0, 0);
}

}  // namespace rex::kernel::xboxkrnl

REX_EXPORT(__imp__DbgBreakPoint, rex::kernel::xboxkrnl::DbgBreakPoint_entry)
REX_EXPORT(__imp__RtlRaiseException, rex::kernel::xboxkrnl::RtlRaiseException_entry)
REX_EXPORT(__imp__KeBugCheckEx, rex::kernel::xboxkrnl::KeBugCheckEx_entry)
REX_EXPORT(__imp__KeBugCheck, rex::kernel::xboxkrnl::KeBugCheck_entry)

REX_EXPORT_STUB(__imp__DbgBreakPointWithStatus);
REX_EXPORT_STUB(__imp__DbgPrompt);
REX_EXPORT_STUB(__imp__DbgLoadImageSymbols);
REX_EXPORT_STUB(__imp__DbgUnLoadImageSymbols);
REX_EXPORT_STUB(__imp__DmPrintData);

REX_EXPORT_STUB(__imp__DumpGetRawDumpInfo);
REX_EXPORT_STUB(__imp__DumpRegisterDedicatedDataBlock);
REX_EXPORT_STUB(__imp__DumpSetCollectionFacility);
REX_EXPORT_STUB(__imp__DumpUpdateDumpSettings);
REX_EXPORT_STUB(__imp__DumpWriteDump);
REX_EXPORT_STUB(__imp__DumpXitThread);
REX_EXPORT_STUB(__imp__RtlAssert);
REX_EXPORT_STUB(__imp__RtlRaiseStatus);
REX_EXPORT_STUB(__imp__RtlRip);
