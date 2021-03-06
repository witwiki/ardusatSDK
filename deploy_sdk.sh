#!/bin/bash
#
# Deploy script to Amazon EC2 storage.
# Removes development files for a "clean" copy
export AWS_DEFAULT_PROFILE=ardusat

# Print usage
function usage() {
  echo -n "$(basename $0) [OPTIONS] [FILE]...
  Deploys a new version of the SDK live to AWS. This makes updates to the 
  CHANGELOG and increments the version.

Options:
  -v, --version-string   Specify a new version string for this version
  -h, --help        Display this help and exit
"
}

function deploy () {
    cd ../
    mkdir tmp_ArdusatSDK
    cp -r ./ArdusatSDK tmp_ArdusatSDK/ArdusatSDK
    cd tmp_ArdusatSDK
    rm -rf ./ArdusatSDK/.git ./ArdusatSDK/decode_binary ./ArdusatSDK/.ycm* ./ArdusatSDK/*.pyc ./deploy_sdk.sh
    zip -r ArdusatSDK.zip ./ArdusatSDK
    aws s3 cp ./ArdusatSDK.zip s3://ardusatweb/ArdusatSDK.zip
    cp -f ArdusatSDK.zip ~/Downloads/ArdusatSDK.zip
    cd ../
    rm -rf ./tmp_ArdusatSDK
}

while getopts "hv:" opt; do
    case $opt in
	h)
	    usage
	    exit 0
	    ;;
	v)
	    version_string=$OPTARG
	    ;;
	\?)
	    echo "Invalid option -$OPTARG"
	    usage
	    exit 1
	    ;;
    esac
done
shift $((OPTIND-1))

if [ -z $version_string ]; then
    default_str=`awk '/##\ \[.*\] -/ { print substr($2, 2, length($2) - 2); exit; }' CHANGELOG.md`
    new_minor_version=$(($(echo $default_str | sed 's/.*\.\([0-9][0-9]*\)$/\1/') + 1))
    default_str=$(echo $default_str | sed 's/\(.*\)\.[0-9][0-9]*$/\1/').$new_minor_version
    echo "Enter a version string ($default_str):"
    read version_string
    if [ -z $version_string ]; then
	version_string=$default_str
    fi
fi

echo "Enter a CHANGELOG description for SDK version $version_string"
FILE=$(mktemp -t $(basename $0));
vim "$FILE";
changelog=`cat $FILE`
rm "$FILE"

echo "CHANGELOG description:"
echo "$changelog"

awk -v v="## [$version_string] - $(date +%Y-%m-%d)" -v d="$changelog\n" 'NR == 4 { print v; print d; } { print }' CHANGELOG.md > CHANGELOG.md.new

mv CHANGELOG.md.new CHANGELOG.md

deploy
