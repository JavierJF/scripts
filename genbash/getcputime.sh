#!/bin/bash

# NAME
# getcputime
#
# SYNOPSIS
# getcputime process_name sleep_duration
#
# DESCRIPTION
# Outputs CPU usage statistics (us and sy) for all processes matching the given name.
#
# ARGUMENTS
# process_name  The name of the process to monitor.
# sleep_duration The duration (in seconds) to sleep between CPU time samples.
#
# RETURN VALUE
# Outputs a string with format - "cpu:%f us_cpu:%f sy_cpu:%d".
#
# EXAMPLE
# getcputime my_process 2
#
# NOTES
# - Requires the 'bc' command for floating-point arithmetic.
# - Relies on the /proc filesystem for process statistics.
# - CLK_TCK value is obtained via 'getconf'. The symbol is obsolete in POSIX, but it's
#   mapped by GNU libc 'getconf' to 'sysconf(_SC_CLK_TCK)', so it should work.
getcputime() {
	local proc=$1
	local secs=$2

	# Input validation
	if [[ -z "$proc" || -z "$secs" ]]; then
		echo "Usage: getcputime <process_name> <sleep_duration>" >&2
		return 1
	fi

	if ! [[ "$secs" =~ ^[0-9]+$ ]]; then
		echo "Error: sleep_duration must be a positive integer" >&2
		return 1
	fi

	local clk_tck=$(getconf CLK_TCK)
	if [[ -z "$clk_tck" ]]; then
		echo "Error: Could not determine CLK_TCK" >&2
		return 1
	fi

	local pids=$(pidof "$proc")
	if [[ -z "$pids" ]]; then
		echo "No processes found with name '$proc'"
		return 1
	fi

	local ini_utime=()
	local ini_stime=()
	local i=0

	for pid in $pids; do
		if ! [[ -r "/proc/$pid/stat" ]]; then
			echo "Warning: Cannot read /proc/$pid/stat. Process may have terminated." >&2
			continue
		fi

		local stats=($(cat "/proc/$pid/stat"))

		# See 'man proc_pid_stat'
		ini_utime[$i]=${stats[13]}
		ini_stime[$i]=${stats[14]}

		((i++))
	done

	sleep $secs

	local fin_utime=()
	local fin_stime=()
	i=0

	for pid in $pids; do
		if ! [[ -r "/proc/$pid/stat" ]]; then
			echo "Warning: Cannot read /proc/$pid/stat. Process may have terminated." >&2
			continue
		fi

		local stats=($(cat "/proc/$pid/stat"))

		# See 'man proc_pid_stat'
		fin_utime[$i]=${stats[13]}
		fin_stime[$i]=${stats[14]}

		((i++))
	done

	local us_cpu=0
	local sy_cpu=0
	i=0

	for pid in $pids; do
		if [[ -z "${ini_utime[$i]}" || -z "${ini_stime[$i]}" ]] || \
			[[ -z "${fin_utime[$i]}" || -z "${fin_stime[$i]}" ]];
		then
			((i++))
			continue
		fi

		us_cpu=$((us_cpu + fin_utime[$i] - ini_utime[$i]))
		sy_cpu=$((sy_cpu + fin_stime[$i] - ini_stime[$i]))

		((i++))
	done

	local sy_cpu_pct=$(echo "scale=2; (100 * $sy_cpu)/($clk_tck * $secs)" | bc -l)
	local us_cpu_pct=$(echo "scale=2; (100 * $us_cpu)/($clk_tck * $secs)" | bc -l)
	local cpu_pct=$(echo "scale=2; $sy_cpu_pct + $us_cpu_pct" | bc -l)

	printf "cpu:%.2f%% us_cpu:%.2f%% sy_cpu:%.2f%%\n" $cpu_pct $us_cpu_pct $sy_cpu_pct
}

getcputime $1 $2
