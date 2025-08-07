#!/bin/bash
clear

# Don't exit on failure — we want to continue on plugin errors
set +e

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

MAX_PARALLEL=6
job_count=0

# Plugins requiring manual arguments
skip_plugins_manual=(
  "regexscan.RegExScan"
  "windows.vadyarascan.VadYaraScan"
  "windows.strings.Strings"
  "windows.pedump.PEDump"
  "timeliner.Timeliner"
)

# Spinner
show_spinner() {
  local pid=$1
  local count=$2
  local total=$3
  local plugin=$4
  local spin='-\|/'
  i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r[%03d/%03d] Running: %-50s [%c]" "$count" "$total" "$plugin" "${spin:$i:1}"
    sleep 0.1
    ((i=(i+1)%4))
  done
}

# Full plugin list
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

for plugin in "${plugins[@]}"; do
  if [[ " ${skip_plugins_manual[*]} " == *" $plugin "* ]]; then
    printf "[SKIP] %-55s requires manual parameters\n" "$plugin"
    ((count++))
    continue
  fi

  if ! vol -h 2>&1 | grep -qw "$plugin"; then
    printf "[SKIP] %-55s is not supported in this Volatility version\n" "$plugin"
    echo "[!] Plugin not found: $plugin" >> "$OUTDIR/ScanErrors.log"
    ((count++))
    continue
  fi

  safe_name="${plugin//./_}"
  csv_file="$CSVDIR/${safe_name}.csv"
  txt_file="$TXTDIR/${safe_name}.txt"
  SECONDS_BEFORE=$(date +%s)

  (
    status_icon="✅"
    status_text="OK"
    if vol -f "$MEMFILE" --renderer=csv "$plugin" > "$csv_file" 2>> "$OUTDIR/ScanErrors.log"; then
      if ! column -s, -t < "$csv_file" > "$txt_file" 2>/dev/null; then
        echo "[!] column failed on $plugin — copying raw CSV" >> "$OUTDIR/ScanErrors.log"
        cp "$csv_file" "$txt_file"
        status_icon="⚠️ "
        status_text="Partial"
      fi
    else
      echo "[!] $plugin failed to execute." >> "$OUTDIR/ScanErrors.log"
      touch "$csv_file" "$txt_file"
      status_icon="❌"
      status_text="Error"
    fi
    SECONDS_AFTER=$(date +%s)
    DURATION=$(echo "$SECONDS_AFTER - $SECONDS_BEFORE" | bc)
    printf "\r[%03d/%03d] %s %-45s (%.2fs - %s)\n" "$count" "$total" "$status_icon" "$plugin" "$DURATION" "$status_text"
  ) &
  pid=$!

  show_spinner $pid "$count" "$total" "$plugin"

  ((job_count++))
  if (( job_count >= MAX_PARALLEL )); then
    while :; do
      running_jobs=$(jobs -r | wc -l | tr -d ' ')
      if (( running_jobs < MAX_PARALLEL )); then
        break
      fi
      sleep 1
    done
  fi

  ((count++))
done

wait

echo ""
echo "✅ All plugin scans complete."
echo "📁 Text results saved to: $TXTDIR"
echo "📁 CSV results saved to:  $CSVDIR"
