#!/bin/bash
#
# build.sh -- Builds Pharo images using a series of Smalltalk
#   scripts. Best to be used together with Hudson.
#
# Copyright (c) 2010 Yanni Chiu <yanni@rogers.com>
# Copyright (c) 2010 Lukas Renggli <renggli@gmail.com>
#

set -e

# vm configuration

if [ -z "$WORKSPACE" ] ; then
	WORKSPACE=`pwd`
fi

# get the current script loction
DIR=`dirname "$0"`;

if [ -z "$PHARO_VM" ] ; then
    export PHARO_VM=`cd "$DIR" && ./pharo-shell-scripts/fetchLatestVM.sh`
    if [ -z "$PHARO_VM" ] ; then
        echo "PHARO_VM environment variable is not set."
        exit 1
    fi
fi

PHARO_PARAM="-nodisplay -nosound"

if [ `uname` == "Darwin" ] || [ "$OS" == "win" ] ; then
	PHARO_PARAM="-headless"
fi

# directory configuration
BUILD_PATH="${WORKSPACE}"

IMAGES_PATH="$WORKSPACE/images"
SCRIPTS_PATH="$WORKSPACE/scripts"
SOURCES_PATH="$WORKSPACE/sources"
BUILD_CACHE="$WORKSPACE/cache"

# build configuration
SCRIPTS=("$SCRIPTS_PATH/before.st")

# help function
function display_help() {
	echo "$(basename $0) -i input -o output {-s script} "
	echo " -i input product name, image from images-directory, or successful hudson build"
	echo " -o output product name"
	echo " -s one or more scripts from the scripts-directory to build the image"
}

# parse options
while getopts ":i:o:s:?" OPT ; do
	case "$OPT" in

		# input
		i)	if [ -f "$BUILD_PATH/$OPTARG/$OPTARG.image" ] ; then
				INPUT_IMAGE="$BUILD_PATH/$OPTARG/$OPTARG.image"
			elif [ -f "$BUILD_PATH/$OPTARG.image" ] ; then
				INPUT_IMAGE="$BUILD_PATH/$OPTARG.image"
			elif [ -f "$IMAGES_PATH/$OPTARG/$OPTARG.image" ] ; then
				INPUT_IMAGE="$IMAGES_PATH/$OPTARG/$OPTARG.image"
			elif [ -f "$IMAGES_PATH/$OPTARG.image" ] ; then
				INPUT_IMAGE="$IMAGES_PATH/$OPTARG.image"
			elif [ -n "$WORKSPACE" ] ; then
				INPUT_IMAGE=`find -L "$WORKSPACE/../.." -name "$OPTARG.image" | grep "/lastSuccessful/" | head -n 1`
			fi

			if [ ! -f "$INPUT_IMAGE" ] ; then
				echo "$(basename $0): input image not found ($OPTARG)"
				exit 1
			fi

			INPUT_CHANGES="${INPUT_IMAGE%.*}.changes"
			if [ ! -f "$INPUT_CHANGES" ] ; then
				echo "$(basename $0): input changes not found ($INPUT_CHANGES)"
				exit 1
			fi
		;;

		# output
		o)	OUTPUT_NAME="$OPTARG"
			OUTPUT_PATH="$BUILD_PATH/$OUTPUT_NAME"
			OUTPUT_SCRIPT="$OUTPUT_PATH/$OUTPUT_NAME.st"
			OUTPUT_IMAGE="$OUTPUT_PATH/$OUTPUT_NAME.image"
			OUTPUT_CHANGES="$OUTPUT_PATH/$OUTPUT_NAME.changes"
			OUTPUT_CACHE="$OUTPUT_PATH/package-cache"
			OUTPUT_DEBUG="$OUTPUT_PATH/PharoDebug.log"
		;;

		# script
		s)	if [ -f "$SCRIPTS_PATH/$OPTARG.st" ] ; then
                SCRIPTS=("${SCRIPTS[@]}" "$SCRIPTS_PATH/$OPTARG.st")
			else
				echo "$(basename $0): invalid script ($OPTARG)"
				exit 1
			fi
		;;

		# show help
		\?)	display_help
			exit 1
		;;

	esac
done

# check required parameters
if [ -z "$INPUT_IMAGE" ] ; then
	echo "$(basename $0): no input product name given"
	exit 1
fi

if [ -z "$OUTPUT_IMAGE" ] ; then
	echo "$(basename $0): no output product name given"
	exit 1
fi

# prepare output path
if [ -d "$OUTPUT_PATH" ] ; then
	rm -rf "$OUTPUT_PATH"
fi
mkdir -p "$OUTPUT_PATH"
mkdir -p "$BUILD_CACHE/${JOB_NAME:=$OUTPUT_NAME}"
ln -s "$BUILD_CACHE/${JOB_NAME:=$OUTPUT_NAME}" "$OUTPUT_CACHE"

# prepare image file and sources
cp "$INPUT_IMAGE" "$OUTPUT_IMAGE"
cp "$INPUT_CHANGES" "$OUTPUT_CHANGES"
find "$SOURCES_PATH" -name "*.sources" -exec ln "{}" "$OUTPUT_PATH/" \;

# prepare script file
SCRIPTS=("${SCRIPTS[@]}" "$SCRIPTS_PATH/after.st")

for FILE in "${SCRIPTS[@]}" ; do
	cat "$FILE" >> "$OUTPUT_SCRIPT"
	echo "!" >> "$OUTPUT_SCRIPT"
done

# make sure we don't have debug log before running image
rm -f "$OUTPUT_DEBUG"

# Ugly hack to deal with backslashes when running in a bash shell on windows
if [ "$OS" == "win" ]; then
    OUTPUT_IMAGE=$(echo ${OUTPUT_IMAGE//\\/\/})
    OUTPUT_SCRIPT=$(echo ${OUTPUT_SCRIPT//\\/\/})
fi

# build image in the background
echo "Executing: 
$PHARO_VM $PHARO_PARAM $OUTPUT_IMAGE $OUTPUT_SCRIPT -headless "

"$PHARO_VM" $PHARO_PARAM "$OUTPUT_IMAGE" "$OUTPUT_SCRIPT" -headless

if [ -f "$OUTPUT_DEBUG" ] ; then

	X=`grep THERE_BE_DRAGONS_HERE "$OUTPUT_DEBUG" | wc -l`
	if [ $X != "0" ] ; then
  		echo "$(basename $0): error loading code ($PHARO_VM)"
  		cat "$OUTPUT_DEBUG" | tr '\r' '\n' | sed 's/^/  /'
  		exit 1
	fi
fi
    

# remove cache link
rm -f "$OUTPUT_CACHE" || echo "Could not remove $OUTPUT_CACHE";
rm -f "$OUTPUT_PATH/*.sources"

# success
exit 0

