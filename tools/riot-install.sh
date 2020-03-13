#!/bin/bash

RIOT_VERSION=1.5.12
RIOT_URL="https://github.com/vector-im/riot-web/releases/download/v${RIOT_VERSION}/riot-v${RIOT_VERSION}.tar.gz"
RIOT_ARCHIVE_PATH="riot.tar.gz"
RIOT_ARCHIVE_DIR="riot-v$RIOT_VERSION"

ERROR_CODE_COULD_NOT_RETRIEVE_RIOT=1
ERROR_CODE_COULD_NOT_EXTRACT_RIOT_TGZ=2
ERROR_CODE_COULD_NOT_MOVE_RIOT_FILES=3

# Use to cleanup every time

bail_out() {
	exit_code=$1
	if [ -f "$RIOT_ARCHIVE_PATH" ];
	then
		rm "$RIOT_ARCHIVE_PATH"
	fi
	if [ -d "$RIOT_ARCHIVE_DIR" ];
	then
		rm -rf "$RIOT_ARCHIVE_DIR"
	fi
	exit $exit_code
}

curl -L "$RIOT_URL" -o "$RIOT_ARCHIVE_PATH"

if [ $? -ne 0 ];
then
	echo "Could not retrieve RIOT at the following address :"
	echo "$RIOT_URL"
	bail_out $ERROR_CODE_COULD_NOT_RETRIEVE_RIOT
fi

tar zxvf "$RIOT_ARCHIVE_PATH"

ls

if [ $? -ne 0 ];
then
	echo "Could not extract the downloaded Riot-web archive"
	bail_out $ERROR_CODE_COULD_NOT_EXTRACT_RIOT_TGZ
fi

mv "$RIOT_ARCHIVE_DIR/"* static/

if [ $? -ne 0 ];
then
	echo "Could not move Riot files in static/"
	echo "Make sure you're running this script from the root"
	echo "of this git repository, using ./tools/riot-install.sh"
	bail_out $ERROR_CODE_COULD_NOT_MOVE_RIOT_FILES
fi

bail_out 0
