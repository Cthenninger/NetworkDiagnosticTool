#!/bin/bash
# Charles Henninger 2020
# Network Connectivity Diagnostic Tool

_DOMAIN=''
_VERBOSE='false'
_USAGE="Help Message"

# Check that the needed commands are installed
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1

elif ! [ -x "$(command -v openssl)" ]; then
  echo 'Error: openssl is not installed.' >&2
  exit 1
fi

# Check that the domain flag was used 
if [[ $* != *"-d "* ]]; then
	echo "Error, no target domain included. Please run again using the -d flag follwed by your target domain"
	exit 1
fi

# Check the flags and get the target domain value
while getopts 'd:v' flag; do
	case "${flag}" in
		d) _DOMAIN="${OPTARG}" ;;
		v) _VERBOSE='true' ;;
		*) echo "$_USAGE"
		   exit 1 ;;
  esac
done


function dnsTest {
	echo "dnsTest"
}

function routeTest {
	# curl -k
	# if http code 300, try curl -k -L
	# if 200, inform of redirect that appears to be working correctly
	# if not, inform of faulty redirect in output
	targetDomain="$1"
	outputCode=$(curl -s -o /dev/null -I -k -w "%{http_code}" $domain)
	echo $output
}

function certificateTest {
	#curl normal
	domain="$1"
	output=$(curl -s -o /dev/null -I -w "%{http_code}" $domain)
	echo $output
}

certificateTest $_DOMAIN
echo $?

