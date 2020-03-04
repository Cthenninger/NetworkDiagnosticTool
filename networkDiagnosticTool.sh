#!/bin/bash
# Charles Henninger 2020
# Network Connectivity Diagnostic Tool

# The request ID (_REQUESTID) is used in a database intended to store results that the console/handler has access to. It is not directly used in this script, but is
# required in the output. If this wasn't an example, the flag for the request ID would be required.
_REQUESTID=""
_RESULT='PASS'
_TESTS=("dnsTest" "routeTest" "certificateTest")
_USAGE="\nnetworkConnectivityDiagnostic Usage: ./networkConnectivityDiagnostic.sh [options...] <url>\n\nOptions:\n\t-r, Request ID (not necessary for this example, see comments)\n"

# Check that the needed commands are installed
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1

elif ! [ -x "$(command -v openssl)" ]; then
  echo 'Error: openssl is not installed.' >&2
  exit 1
fi

# Check the flags and get the target domain value.
while getopts 'r:h' flag; do
	case "${flag}" in
		r) shift
		_REQUESTID="${OPTARG}" 
		shift ;;
		h) echo -e "$_USAGE"
		exit 0 ;;
		*) echo -e "$_USAGE"
		exit 1 ;;
  esac
done

_DOMAIN="$1"
# Check that a domain was passed in.
if [ -z "$_DOMAIN" ]; then
	echo "Error, no target domain included. For usage information, try ./networkConnectivityDiagnostic.sh -h"
	exit 1
fi

# Remove any URL schemes that were included in the target domain 
# Also removes any trailing forward slashes.
if [[ $_DOMAIN == *"https://"* ]]; then
	_DOMAIN="${_DOMAIN:8}"
elif [[ $_DOMAIN == *"http://"* ]]; then
	_DOMAIN="${_DOMAIN:7}"
elif [[ $_DOMAIN == *"www."* ]]; then
	_DOMAIN="${_DOMAIN:4}"
fi
if [[ $_DOMAIN == *"/" ]]; then
	_DOMAIN="${_DOMAIN::-1}"
fi

# This test uses dig to check DNS name servers for the target domain. If this fails, it's usually a NXDOMAIN error, meaning that a domain by that name cannot be found. 
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

# The route test is to check if a valid connection can be established from this network. The '-k' flag we use is to ignore insecure connections, as we really only want to check
# if a connection is possible in this test.
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

# Similar to the route test, the Certificate test uses cURL's default SSL connection to see if a connection is secure. This will report some of the more common errors associated 
# with domain certificates, such as an expired certificate or a certificate that has not been properly authorized.
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

# One of the requirements for this feature was the ability to add or remove tests as needed based on feedback from customers. This loop runs every test located in the _TESTS list. All
# that is required to add a test is to add the test's function above, and add it's function name into the _TESTS list. 
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

