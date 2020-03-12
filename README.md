# NetworkDiagnosticTool
Simplified example of a tool I help develop while working at AWS WorkLink

This tool is designed to run three of the tests we chose to include based on customer feedback: DNS test, Route test, and a Certification test. The main requirements for this project were: 1) Ability to easily add and remove tests as needed 2) Needs to be in bash  

The script is functional as is, provided you have the few required commands installed (and bash, of course). Written on Ubuntu Bash Shell. Output is standard JSON. 

Usage: ./networkConnectivityDiagnostic.sh [options...] <url>You can run this script by saving it as an executable and running it as normal 

badssl.com has some good resources to try this script with. 
