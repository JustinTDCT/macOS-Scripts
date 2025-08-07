#!/bin/bash
clear

# Exit on error
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 memory_dump.raw"
  exit 1
fi

MEMFILE="$1"
BASENAME=$(basename "$MEMFILE")
FILETIME=$(stat -f "%SB" -t "%Y-%m-%d_%H_%M" "$MEMFILE")
OUTDIR="DUMP_${BASENAME}_${FILETIME}"
TXTDIR="$OUTDIR/TXT"
CSVDIR="$OUTDIR/CSV"

mkdir -p "$TXTDIR" "$CSVDIR"

# Plugins that require special arguments (skip)
skip_plugins_manual=(
  "regexscan.RegExScan"
  "windows.vadyarascan.VadYaraScan"
  "windows.strings.Strings"
  "windows.pedump.PEDump"
  "timeliner.Timeliner"
)

# Full plugin list (minus "windows.cmdscan.CmdScan", which doesn't exist in v2.26.2)
plugins=(
  "regexscan.RegExScan"
  "timeliner.Timeliner"
  "vmscan.Vmscan"
  "windows.amcache.Amcache"
  "windows.bigpools.BigPools"
  "windows.cachedump.Cachedump"
  "windows.callbacks.Callbacks"
  "windows.cmdline.CmdLine"
  "windows.consoles.Consoles"
  "windows.crashinfo.Crashinfo"
  "windows.debugregisters.DebugRegisters"
  "windows.deskscan.DeskScan"
  "windows.desktops.Desktops"
  "windows.devicetree.DeviceTree"
  "windows.direct_system_calls.DirectSystemCalls"
  "windows.dlllist.DllList"
  "windows.driverirp.DriverIrp"
  "windows.drivermodule.DriverModule"
  "windows.driverscan.DriverScan"
  "windows.dumpfiles.DumpFiles"
  "windows.envars.Envars"
  "windows.etwpatch.EtwPatch"
  "windows.filescan.FileScan"
  "windows.getservicesids.GetServiceSIDs"
  "windows.getsids.GetSIDs"
  "windows.handles.Handles"
  "windows.hashdump.Hashdump"
  "windows.hollowprocesses.HollowProcesses"
  "windows.iat.IAT"
  "windows.indirect_system_calls.IndirectSystemCalls"
  "windows.info.Info"
  "windows.joblinks.JobLinks"
  "windows.kpcrs.KPCRs"
  "windows.ldrmodules.LdrModules"
  "windows.lsadump.Lsadump"
  "windows.malfind.Malfind"
  "windows.malware.direct_system_calls.DirectSystemCalls"
  "windows.malware.drivermodule.DriverModule"
  "windows.malware.hollowprocesses.HollowProcesses"
  "windows.malware.indirect_system_calls.IndirectSystemCalls"
  "windows.malware.ldrmodules.LdrModules"
  "windows.malware.malfind.Malfind"
  "windows.malware.processghosting.ProcessGhosting"
  "windows.malware.psxview.PsXView"
  "windows.malware.skeleton_key_check.Skeleton_Key_Check"
  "windows.malware.suspicious_threads.SuspiciousThreads"
  "windows.malware.svcdiff.SvcDiff"
  "windows.malware.unhooked_system_calls.UnhookedSystemCalls"
  "windows.mbrscan.MBRScan"
  "windows.mftscan.ADS"
  "windows.mftscan.MFTScan"
  "windows.mftscan.ResidentData"
  "windows.modscan.ModScan"
  "windows.modules.Modules"
  "windows.mutantscan.MutantScan"
  "windows.netscan.NetScan"
  "windows.netstat.NetStat"
  "windows.orphan_kernel_threads.Threads"
  "windows.pe_symbols.PESymbols"
  "windows.pedump.PEDump"
  "windows.poolscanner.PoolScanner"
  "windows.privileges.Privs"
  "windows.processghosting.ProcessGhosting"
  "windows.pslist.PsList"
  "windows.psscan.PsScan"
  "windows.pstree.PsTree"
  "windows.psxview.PsXView"
  "windows.registry.amcache.Amcache"
  "windows.registry.cachedump.Cachedump"
  "windows.registry.certificates.Certificates"
  "windows.registry.getcellroutine.GetCellRoutine"
  "windows.registry.hashdump.Hashdump"
  "windows.registry.hivelist.HiveList"
  "windows.registry.hivescan.HiveScan"
  "windows.registry.lsadump.Lsadump"
  "windows.registry.printkey.PrintKey"
  "windows.registry.scheduled_tasks.ScheduledTasks"
  "windows.registry.userassist.UserAssist"
  "windows.scheduled_tasks.ScheduledTasks"
  "windows.sessions.Sessions"
  "windows.shimcachemem.ShimcacheMem"
  "windows.skeleton_key_check.Skeleton_Key_Check"
  "windows.ssdt.SSDT"
  "windows.statistics.Statistics"
  "windows.strings.Strings"
  "windows.suspended_threads.SuspendedThreads"
  "windows.suspicious_threads.SuspiciousThreads"
  "windows.svcdiff.SvcDiff"
  "windows.svclist.SvcList"
  "windows.svcscan.SvcScan"
  "windows.symlinkscan.SymlinkScan"
  "windows.thrdscan.ThrdScan"
  "windows.threads.Threads"
  "windows.timers.Timers"
  "windows.truecrypt.Passphrase"
  "windows.unhooked_system_calls.unhooked_system_calls"
  "windows.unloadedmodules.UnloadedModules"
  "windows.vadinfo.VadInfo"
  "windows.vadregexscan.VadRegExScan"
  "windows.vadwalk.VadWalk"
  "windows.vadyarascan.VadYaraScan"
  "windows.verinfo.VerInfo"
  "windows.virtmap.VirtMap"
  "windows.windows.Windows"
  "windows.windowstations.WindowStations"
)

total=${#plugins[@]}
count=1

echo "🧪 Starting Volatility3 scan on: $MEMFILE"
echo "📂 Output will be saved to: $OUTDIR"
echo "📦 Total plugins to run: $total"
echo ""

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\\'
  while kill -0 "$pid" 2>/dev/null; do
    for ((i = 0; i < ${#spinstr}; i++)); do
      printf "\r[%3d/%3d] Running: %-50s [%c]" "$count" "$total" "$plugin" "${spinstr:$i:1}"
      sleep $delay
    done
  done
  printf "\r%*s\r" $(tput cols) ""  # clear line
}

for plugin in "${plugins[@]}"; do
  if [[ " ${skip_plugins_manual[*]} " == *" $plugin "* ]]; then
    printf "[SKIP] %-55s requires manual parameters\n" "$plugin"
    ((count++))
    continue
  fi

  # Check if plugin is available
  if ! vol -h 2>&1 | grep -qw "$plugin"; then
    printf "[SKIP] %-55s is not supported in this version of Volatility\n" "$plugin"
    echo "[!] Plugin not found: $plugin" >> "$OUTDIR/ScanErrors.log"
    ((count++))
    continue
  fi

  safe_name="${plugin//./_}"
  csv_file="$CSVDIR/${safe_name}.csv"
  txt_file="$TXTDIR/${safe_name}.txt"

  vol -f "$MEMFILE" --renderer=csv "$plugin" > "$csv_file" 2>> "$OUTDIR/ScanErrors.log" &
  pid=$!
  spinner $pid
  wait $pid
  exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    if ! column -s, -t < "$csv_file" > "$txt_file" 2>/dev/null; then
      echo "[!] column failed on $plugin — copying raw CSV as TXT instead" >> "$OUTDIR/ScanErrors.log"
      cp "$csv_file" "$txt_file"
    fi
    printf "[%3d/%3d] ✅ %s\n" "$count" "$total" "$plugin"
  else
    printf "[%3d/%3d] ❌ %s (exit code %d)\n" "$count" "$total" "$plugin" "$exit_code"
    echo "[!] $plugin failed with exit code $exit_code" >> "$OUTDIR/ScanErrors.log"
    touch "$csv_file" "$txt_file"
  fi

  ((count++))
done

echo ""
echo "✅ All plugin scans complete."
echo "📁 Text results saved to: $TXTDIR"
echo "📁 CSV results saved to:  $CSVDIR"
