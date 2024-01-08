#!/bin/bash
#	
# Author: Andreas Schroeer
# Mail: aeschroeer@avaya.com
#
# sshtest.sh is a bash script to check the cryptographic algorythms used by a ssh server.
#
# sshtest.sh needs an input-file with the ip-addresses and ports to scan with a semicolon as separator:
# ip-address;port
# ip-address;port
# .......
#
# sshtest.sh generates an output-file with the result as a comma separated values file.
# The following values are currently logged in the file:
# - SSH-Version
# - Key Exchange Algorythms
# - Host Key Algorythms
# - Cipher Suites
# - Hash Algorythm
#
# The sshtest.sh scipt and the input-file need to be in the same folder.
# The output-file will be stored in the same folder.

set -eu

# Ask user for filename with hosts and ports to scan
echo "Please enter the filename with hosts to scan:"
read -r hosts

# Date and time setting to append to output filename
dati=$(date '+%Y%m%d_%H%M%S')

# Declare output filename
outputfile=${hosts%%.*}"_sshtest_$dati.csv"

# Perform a scan to each host and port from delivered file and create output csv file
# sed removes carriage return if inside file before performing the scans
sed -r -e 's/\r//g' "$hosts" |
while read -r -d';' host && read -r port; do
    tempfile=$(mktemp)
    # Write scanned host and port into tempfile
    echo "Host: ""$host","$port" >> "$tempfile"
    # Perfomr ssh scan and write output into tempfile
    ssh -vv -o BatchMode=yes -p "$port" "$host" >> "$tempfile" 2>&1 || true
    # Copy only lines into outputfile beginning with Host: and debug1:
    grep -E -e "^Host:" -e "^debug1: Remote protocol" "$tempfile" >> "$outputfile"
    # Copy line beginning with "debug2: peer server" plus the following 6 lines into outputfile
    grep -E -A 6 "^debug2: peer server" "$tempfile" >> "$outputfile"
    rm "$tempfile"
done

# Remove unnecessary information
# First expression > Remove line "peer server KEXINIT"
# Second expression > Change name of first value in line beginnig with "debug1:"
# Third expression > Remove value "debug2:" from each line affected
sed -i -E -e '/peer server KEXINIT/d' -e 's/^debug1: /SSH Version,/' -e 's/^debug2: //' -e 's/: /,/g' "$outputfile"