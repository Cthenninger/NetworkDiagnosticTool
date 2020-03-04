#!/bin/bash
# Charles Henninger 2020
# Network Connectivity Diagnostic Tool

_DOMAIN=''
_READABLE='false'
_REQUESTID=""
_RESULT='PASS'
_TESTS=("dnsTest" "routeTest" "certificateTest")
_USAGE="Help Message"
_VERBOSE='false'

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
while getopts 'd:vri:' flag; do
	case "${flag}" in
		d) _DOMAIN="${OPTARG}" ;;
		v) _VERBOSE='true' ;;
		r) _READABLE='true';;
		i) _REQUESTID="${OPTARG}" ;;
		*) echo "$_USAGE"
		   exit 1 ;;
  esac
done

# Remove any URL schemes that were included in the target domain 
# Also auto removes any trailing forwardslashes
if [[ $_DOMAIN == *"https://"* ]]; then
	_DOMAIN="${_DOMAIN:8}"
elif [[ $_DOMAIN == *"http://"* ]]; then
	_DOMAIN="${_DOMAIN:7}"
elif [[ $_DOMAIN == *"www."* ]]; then
	_DOMAIN="${_DOMAIN:4}"
fi
if [[ $_DOMAIN == *".com/" ]]; then
	_DOMAIN="${_DOMAIN::-1}"
fi

function dnsTest {
	exitCode=0
	result="PASS"
	targetDomain="$1"
	dnsOutput=$(dig $targetDomain)
	digStatusWithJunk=${dnsOutput#*"status: "}
	digStatus=$(echo $digStatusWithJunk | cut -d, -f1)
	if [ "$digStatus" != "NOERROR" ]; then
		result="FAIL"
		exitCode=1
	fi
	echo "{\"TEST\": \"DNS Test\", \"RESULT\":\"$result\", \"OUTPUT\":\"$digStatus\"}"
	exit $exitCode
}

function routeTest {
	exitCode=0
	result="PASS"
	targetDomain="https://$1"
	outputCode=$(curl -s -o /dev/null -I -k -w "%{http_code}" $targetDomain)
	# These are the major errors that we want to fail on. 000 is usually a networking related error, and any code above 400 is also a notable error.
	if [[ $outputCode -eq 000 ]] || [[ $outputCode -ge 400 ]]; then
		curlMessage=$(curl -s --show-error $targetDomain) 
		result="FAIL"
		exitCode=1
	
	# This is to gather as much information as we can for the user. Including any redirection notices we find along with the overall outcome can help in some cases. 
	elif [ $outputCode -ge 300 ] && [ $outputCode -lt 400 ]; then
		codeAfterRedirect=$(curl -L -s -o /dev/null -I -k -w "%{http_code}" $targetDomain)
		if [ $codeAfterRedirect -eq 000 ] || [ $codeAfterRedirect -ge 400 ]; then
			additionalInfo=", \"INFO\": \"Redirected initially with a code of $outputCode. Following the redirection resulted in a code of $codeAfterRedirect\""
			exitCode=1
		fi
		additionalInfo=", \"INFO\": \"Redirected initially with a code of $outputCode. Following the redirection resulted in a code of $codeAfterRedirect\""
	fi
	
	echo "{\"TEST\": \"Route Test\", \"RESULT\":\"$result\", \"OUTPUT\":\"$outputCode\"$additionalInfo}"
	exit $exitCode
}

function certificateTest {
	exitCode=0
	result="PASS"
	targetDomain="https://$1"
	certOutput=$(curl -s -o /dev/null -I -w "%{http_code}" $targetDomain)
	if [ $certOutput -eq 000 ] || [ $certOutput -ge 400 ]; then
		curlMessage=$(curl $targetDomain 2>&1 | grep curl:) 
		additionalInfo=", \"INFO\":\"$curlMessage\""
		result="FAIL"
		exitCode=1
	fi
	echo "{\"TEST\": \"Cert Test\", \"RESULT\":\"$result\", \"OUTPUT\":\"$certOutput\"$additionalInfo}"
	exit $exitCode
}

testOutput=""
for test in ${_TESTS[@]}; do
	output=$($test $_DOMAIN)
	# It is very important that this is directly after the function call. Otherwise we'd be getting the exit code of some other command.
	testExitCode=$?
	testOutput="$testOutput$output,"
	if [ $testExitCode -gt 0 ]; then
		_RESULT='FAIL'
		break
	fi
done

jsonOutput="{\"DOMAIN\":\"$_DOMAIN\", \"REQUEST_ID\": \"$_REQUESTID\", \"RESULT\": \"$_RESULT\", \"TEST_OUTPUT\":[${testOutput::-1}]}"
echo "$jsonOutput"
exit 0

