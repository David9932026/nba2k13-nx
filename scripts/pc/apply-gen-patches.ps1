# 每次 codegen 重新生成后，重新打上对生成代码的补丁（codegen 会覆盖）
# 用法: powershell -File apply-gen-patches.ps1
# 注意：
#  1) 生成文件是 LF 换行，匹配必须用 \r?\n，不能用 `r`n 字面量。
#  2) 只在指定函数体内打补丁，绝不全局替换（全局替换会误伤上千个函数）。
$ErrorActionPreference = 'Stop'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$gen = Join-Path $proj 'rex\nba2k13app\generated\default'

function Get-FuncBlock([string]$text, [string]$funcName) {
  $start = $text.IndexOf("DEFINE_REX_FUNC($funcName) {")
  if ($start -lt 0) { return $null }
  # 生成函数以行首的单独 "}" 结束
  $end = $text.IndexOf("`n}", $start)
  if ($end -lt 0) { return $null }
  return @{ Start = $start; End = $end + 2 }
}

$totalHits = 0
Get-ChildItem $gen -Filter 'nba2k13_recomp.*.cpp' | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName)
  $orig = $t
  $fileHits = 0

  # ---------- sub_82C32D50: 双向链表摘除容错 ----------
  $b = Get-FuncBlock $t 'sub_82C32D50'
  if ($b) {
    $body = $t.Substring($b.Start, $b.End - $b.Start)
    $newBody = $body

    $p1 = "\t// stw r9,12\(r8\)\r?\n\tREX_STORE_U32\(ctx\.r8\.u32 \+ 12, ctx\.r9\.u32\);\r?\n"
    $r1 = @'
	// PATCH(cola): tolerant unlink - node may already be detached (double remove)
	if (ctx.r8.u32) {
		REX_STORE_U32(ctx.r8.u32 + 12, ctx.r9.u32);
	} else {
		REXCPU_WARN("double remove: node 0x{:08X} already detached (next=0)", ctx.r4.u32);
	}
'@ -replace "`r`n", "`n"
    $newBody = [regex]::Replace($newBody, $p1, { param($m) $r1 })

    $p2 = "\t// stw r6,8\(r7\)\r?\n\tREX_STORE_U32\(ctx\.r7\.u32 \+ 8, ctx\.r6\.u32\);\r?\n"
    $r2 = @'
	// PATCH(cola): tolerant unlink - prev may be detached as well
	if (ctx.r7.u32) {
		REX_STORE_U32(ctx.r7.u32 + 8, ctx.r6.u32);
	} else {
		REXCPU_WARN("double remove: prev already detached (node 0x{:08X})", ctx.r4.u32);
	}
'@ -replace "`r`n", "`n"
    $newBody = [regex]::Replace($newBody, $p2, { param($m) $r2 })

    if ($newBody -ne $body) {
      $t = $t.Substring(0, $b.Start) + $newBody + $t.Substring($b.End)
      $fileHits++
    }
  }

  # ---------- sub_82292FD8: dt 钳位（子步数 = ceil(rate*|dt|)，卡一下就死亡螺旋） ----------
  $b = Get-FuncBlock $t 'sub_82292FD8'
  if ($b) {
    $body = $t.Substring($b.Start, $b.End - $b.Start)
    if ($body -notmatch 'PATCH\(cola\): dt clamp') {
      $p = "\t// stfs f1,380\(r31\)\r?\n"
      $r = @'
	// PATCH(cola): dt clamp. Substeps here are ceil(rate*|dt|) (vrfip on [r29+60]*|f1|),
	// so after one long frame (loading, pipeline build) dt grows, the next frame gets
	// more substeps, and the game falls into a death spiral (Switch: 60 -> 0.5 fps).
	// Clamp to 1/30 s: the effect slows down instead of eating the frame.
	if (ctx.f1.f64 > (1.0 / 30.0)) ctx.f1.f64 = 1.0 / 30.0;
	else if (ctx.f1.f64 < -(1.0 / 30.0)) ctx.f1.f64 = -(1.0 / 30.0);
	// stfs f1,380(r31)

'@ -replace "`r`n", "`n"
      $newBody = [regex]::Replace($body, $p, { param($m) $r }, 1)
      if ($newBody -ne $body) {
        $t = $t.Substring(0, $b.Start) + $newBody + $t.Substring($b.End)
        $fileHits++
      }
    }
  }

  # ---------- sub_82292FD8: substep cap (N4g, src/cola_subpasos.cpp) ----------
  $b = Get-FuncBlock $t 'sub_82292FD8'
  if ($b) {
    $body = $t.Substring($b.Start, $b.End - $b.Start)
    if ($body -notmatch 'PATCH\(cola\): substep cap') {
      $p = "(\t// vrfip128 v49,v50\r?\n[^\r\n]*\r?\n)"
      $r = @'
$1	// PATCH(cola): substep cap (N4g). n = ceil(rate*dt) lives in v49; the step size is derived
	// from it below, so capping it keeps the integrated time. See src/cola_subpasos.cpp.
	ColaSubpasos(ctx.v49.f32, ctx.v54.f32[0], ctx.v53.f32[0], ctx.v56.f32, ctx.v52.f32, ctx.v51.f32);

'@ -replace "`r`n", "`n"
      $newBody = [regex]::Replace($body, $p, $r, 1)
      if ($newBody -ne $body) {
        $decl = "// PATCH(cola): substep cap declaration`nextern `"C`" void ColaSubpasos(float*, float, float, float*, float*, float*);`n`n"
        $t = $t.Substring(0, $b.Start) + $decl + $newBody + $t.Substring($b.End)
        $fileHits++
      }
    }
  }

  # ---------- sub_82C33C50: 空 item 保护（原来读 guest 0x18 崩） ----------
  $b = Get-FuncBlock $t 'sub_82C33C50'
  if ($b) {
    $body = $t.Substring($b.Start, $b.End - $b.Start)
    $p3 = "(\t// lwz r4,0\(r5\)\r?\n\tctx\.r4\.u64 = REX_LOAD_U32\(ctx\.r5\.u32 \+ 0\);\r?\n)"
    $guard = @'
	// PATCH(cola): null item guard (was crashing with read of guest 0x18)
	if (!ctx.r4.u32) {
		REXCPU_WARN("null content item in sub_82C33C50, skipping via guest epilogue");
		// The frame and r27-r31/LR were already saved: never return without unwinding.
		goto loc_82C33D7C;
	}
'@ -replace "`r`n", "`n"
    if ($body.Contains('// PATCH(cola): null item guard')) {
      # Upgrade the old bare-return guard in place; do not insert a second guard.
      $oldGuard = '\t// PATCH\(cola\): null item guard[^\r\n]*\r?\n\tif \(!ctx\.r4\.u32\) \{\s*REXCPU_WARN\([^\r\n]*\);\s*return;\s*\}'
      $newBody = [regex]::Replace($body, $oldGuard, { param($m) $guard })
    } else {
      $newBody = [regex]::Replace($body, $p3, { param($m) $m.Value + $guard + "`n" }, 1)
    }
    if ($newBody -ne $body) {
      $t = $t.Substring(0, $b.Start) + $newBody + $t.Substring($b.End)
      $fileHits++
    }
  }

  if ($t -ne $orig) {
    $totalHits++
    Write-Output "patched $($_.Name) ($fileHits)"
    [System.IO.File]::WriteAllText($_.FullName, $t, (New-Object System.Text.UTF8Encoding($false)))
  }
}
"done, $totalHits file(s) patched"
