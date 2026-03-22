#!/system/bin/sh
# Wait for boot to complete
until [ "$(getprop sys.boot_completed)" -eq 1 ]; do
    sleep 5
done

# Fix for MODDIR in some environments
MODDIR=${0%/*}
[ "$MODDIR" = "/system/bin" ] && MODDIR="/data/adb/modules/cpu_gpu_perf_manual"

PROP_FILE="$MODDIR/module.prop"
DEFAULTS_DIR="$MODDIR/defaults"
mkdir -p "$DEFAULTS_DIR"

# 1. Clean up stale state
rm -f "$MODDIR/perf_enabled"

# 2. Backup Default Governors at Boot
cpu_govs=""
for policy in /sys/devices/system/cpu/cpufreq/policy[0-9]*; do
    [ -d "$policy" ] || continue
    p_num=$(basename "$policy" | sed 's/policy//')
    gov=$(cat "$policy/scaling_governor")
    echo "$gov" > "$DEFAULTS_DIR/cpu_p$p_num"
    cpu_govs="$cpu_govs P$p_num:$gov "
done

# 3. Backup Default GPU Governor
gpu_gov="Not Found"
for path in /sys/class/kgsl/kgsl-3d0/devfreq/governor /sys/class/devfreq/*.gpu/governor /sys/class/devfreq/gpufreq/governor; do
    if [ -f "$path" ]; then
        echo "$path" > "$DEFAULTS_DIR/gpu_path"
        gov=$(cat "$path")
        echo "$gov" > "$DEFAULTS_DIR/gpu_gov"
        gpu_gov="$gov"
        break
    fi
done

# 4. Backup Default Top-App Cpuset
top_app_cpus="N/A"
if [ -f "/dev/cpuset/top-app/cpus" ]; then
    top_app_cpus=$(cat /dev/cpuset/top-app/cpus)
    echo "$top_app_cpus" > "$DEFAULTS_DIR/top_app_cpus"
fi

# 5. Initial Description Update
new_desc="Status: Balanced | $cpu_govs| GPU: $gpu_gov | Top-App: $top_app_cpus"
sed -i "s@^description=.*@description=$new_desc@" "$PROP_FILE"
