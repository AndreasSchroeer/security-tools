#!/bin/bash
#	
# Author: Andreas Schroeer
# Mail: aeschroeer@avaya.com
#
# tlstest.sh is a bash script to automate the script testssl.sh which you can find at
# https://github.com/drwetter/testssl.sh/releases
# 
# testssl.sh must be installed in the folder /opt/testssl/
#
# tlstest.sh needs an input-file with the ip-addresses and ports to scan with a semicolon as separator:
# ip-address;port
# ip-address;port
# .......
#
# tlstest.sh generates an output-file with the result as a comma separated values file.
# The following values are currently logged in the file:
# - Certificate hash algorithm
# - Certificate key size
# - TLS-Version
# - TLS Cipher-Suites
#
# The tlstest.sh scipt and the input-file need to be in the same folder.
# The output-file will be stored in the same folder.

set -eu

main() {
	echo "Please enter the filename with hosts to scan:"
	read -r hosts

	# Date and time setting to append to output filename
	dati=$(date '+%Y%m%d_%H%M%S')

	# Declare output filename
	outputfile="${hosts%%.*}_tlstest_$dati.csv"
	errorfile="${hosts%%.*}_tlstest_$dati.err"

	# Perform a scan to each host and port from delivered file and create output csv file
	# sed removes carriage return if inside file before performing the scans
	sed -r -e 's/\r//g' "$hosts" |
	while read -r -d';' host && read -r port; do
		testssl_scan "$host" "$port" "$outputfile" "$errorfile"
	done

	# Remove unnecessary information
	# First expression > Change / into a separator to separate FQDN and IP-Address
	# Second expression > Change three spaces into a separator
	# Third expression > Print only lines beginning with "cipher to outputfile
	# Fourth expression > Print only lines beginning with "cert_signatureAlgorithm to outputfile
	# Fifth expression > Print only lines beginning with "cert_keySize to outputfile
	sed -i -r -n -e 's/[/]/","/' -e 's/  +/","/g' -e '/"cipher.*/p' -e '/"cert_signatureAlgorithm.*/p' -e '/"cert_keySize.*/p' "$outputfile"
	# First expression > Remove ,"","" inside the file to remove empty fields
	# Second experession > Remove unecessary information
	sed -i -e 's/,"",""//g' -e 's/ (exponent is 65537)//g' "$outputfile"

	# Set temporary file
	tempfile=$(mktemp)

	# Remove unnecessary columns > Copy only needed columns inside temporary file
	cut -d',' -f1-4,6-11 "$outputfile" > "$tempfile"

	# Add titles to the first line
	firstline="testssl NAME","FQDN","IP-Address","Port","Value","IANA-Notation","Cipher-Suite","Key Exchange","Encryption Algorythm","Encryption Key Size"

	# Write tempfile to outputfile
	echo "$firstline" | cat - "$tempfile" > "$outputfile"

	print_errorlog "$errorfile"
}

# $1: Hostname or IP-address
# $2: Portnumber
# $3: Name of Outputfile
# $4: Name of errorfile
testssl_scan() {
	/opt/testssl.sh/testssl.sh --quiet -E -S --mapping no-openssl --csvfile "$3" --append "$1":"$2" 2>>"$4" || {
		echo "Error occured, please view error log $4"
	}
}

# $1: Name of errorfile
print_errorlog() {
	echo "Content from errorlog $1"
	echo "----------------------------------"
	echo
	cat "$1"
}

main "$@"