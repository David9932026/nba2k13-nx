Add-Type -Namespace W -Name N -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("kernel32", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Ansi)]
public static extern System.IntPtr LoadLibraryA(string path);
[System.Runtime.InteropServices.DllImport("kernel32", SetLastError=true, CharSet=System.Runtime.InteropServices.CharSet.Ansi)]
public static extern System.IntPtr GetProcAddress(System.IntPtr h, string name);
"@
$dll = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release\rexgpu-xenos.dll'
"LoadLibraryA ..."
$h = [W.N]::LoadLibraryA($dll)
"句柄 = $h   错误 = $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
if ($h -ne [System.IntPtr]::Zero) {
  $p = [W.N]::GetProcAddress($h, 'rex_gpu_abi_version')
  "rex_gpu_abi_version @ $p"
  if ($p -ne [System.IntPtr]::Zero) {
    $abi = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($p, [Func[uint32]])
    "ABI = $($abi.Invoke())"
  }
}
