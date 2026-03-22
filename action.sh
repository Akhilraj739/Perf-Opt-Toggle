#!/system/bin/sh
MODDIR=${0%/*}
[ "$MODDIR" = "/system/bin" ] && MODDIR="/data/adb/modules/cpu_gpu_perf_manual"

PERF_FLAG="$MODDIR/perf_enabled"
PROP_FILE="$MODDIR/module.prop"
DEFAULTS_DIR="$MODDIR/defaults"

# Function to update description with live data
update_desc() {
    local status=$1

    # CPU Govs
    local cpu_govs=""
    for policy in /sys/devices/system/cpu/cpufreq/policy[0-9]*; do
        [ -d "$policy" ] || continue
        p_num=$(basename "$policy" | sed 's/policy//')
        gov=$(cat "$policy/scaling_governor")
        cpu_govs="$cpu_govs P$p_num:$gov "
    done

    # GPU Gov
    local gpu_gov="Not Found"
    for path in /sys/class/kgsl/kgsl-3d0/devfreq/governor /sys/class/devfreq/*.gpu/governor /sys/class/devfreq/gpufreq/governor; do
        if [ -f "$path" ]; then
            gpu_gov=$(cat "$path")
            break
        fi
    done

    # Top-App Cpuset
    local top_cpus="N/A"
    [ -f "/dev/cpuset/top-app/cpus" ] && top_cpus=$(cat /dev/cpuset/top-app/cpus)

    local new_desc="Status: $status | $cpu_govs| GPU: $gpu_gov | Top-App: $top_cpus"
    sed -i "s@^description=.*@description=$new_desc@" "$PROP_FILE"
}

# Toggle Logic
if [ -f "$PERF_FLAG" ]; then
    # --- RESTORE TO BALANCED ---
    rm -f "$PERF_FLAG"

    # Restore CPU
    for f in "$DEFAULTS_DIR"/cpu_p*; do
        [ -f "$f" ] || continue
        p_num=$(basename "$f" | sed 's/cpu_p//')
        [ -d "/sys/devices/system/cpu/cpufreq/policy$p_num" ] && cat "$f" > "/sys/devices/system/cpu/cpufreq/policy$p_num/scaling_governor"
    done

    # Restore GPU
    if [ -f "$DEFAULTS_DIR/gpu_path" ]; then
        gpu_path=$(cat "$DEFAULTS_DIR/gpu_path")
        [ -f "$gpu_path" ] && cat "$DEFAULTS_DIR/gpu_gov" > "$gpu_path"
    fi

    # Restore Top-App Cpuset
    if [ -f "$DEFAULTS_DIR/top_app_cpus" ]; then
        cat "$DEFAULTS_DIR/top_app_cpus" > /dev/cpuset/top-app/cpus
    fi

    update_desc "Balanced"
    echo "Module Status: Balanced"
else
    # --- ENABLE PERFORMANCE ---
    touch "$PERF_FLAG"

    # Set CPU Clusters
    for policy in /sys/devices/system/cpu/cpufreq/policy[0-9]*; do
        [ -d "$policy" ] || continue
        if grep -q "performance" "$policy/scaling_available_governors"; then
            echo "performance" > "$policy/scaling_governor"
        fi
    done

    # Set GPU
    for path in /sys/class/kgsl/kgsl-3d0/devfreq/governor /sys/class/devfreq/*.gpu/governor /sys/class/devfreq/gpufreq/governor; do
        if [ -f "$path" ]; then
            if grep -q "performance" "${path%/*}/available_governors"; then
                echo "performance" > "$path"
            fi
            break
        fi
    done

    # Restrict Top-App to Big/Prime cores (4-7)
    if [ -f "/dev/cpuset/top-app/cpus" ]; then
        echo "4-7" > /dev/cpuset/top-app/cpus
    fi

    update_desc "Performance"
    echo "Module Status: Performance"
fi
