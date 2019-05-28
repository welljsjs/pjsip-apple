#!/bin/sh

# see http://stackoverflow.com/a/3915420/318790
function realpath { echo $(cd $(dirname "$1"); pwd)/$(basename "$1"); }
__FILE__=`realpath "$0"`
__DIR__=`dirname "${__FILE__}"`

# download
function download() {
    "${__DIR__}/download.sh" "$1" "$2" #--no-cache
}

DEVELOPER=$(xcode-select --print-path)

IPHONEOS_DEPLOYMENT_VERSION="9.0"
IPHONEOS_PLATFORM=$(xcrun --sdk iphoneos --show-sdk-platform-path)
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)

IPHONESIMULATOR_PLATFORM=$(xcrun --sdk iphonesimulator --show-sdk-platform-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

OSX_DEPLOYMENT_VERSION="10.8"
OSX_PLATFORM=$(xcrun --sdk macosx --show-sdk-platform-path)
OSX_SDK=$(xcrun --sdk macosx --show-sdk-path)

BASE_DIR="$1"
PJSIP_URL="http://www.pjsip.org/release/2.8/pjproject-2.8.tar.bz2"
PJSIP_DIR="$1/src"
LIB_PATHS=("pjlib/lib" \
           "pjlib-util/lib" \
           "pjmedia/lib" \
           "pjnath/lib" \
           "pjsip/lib" \
           "third_party/lib")

OPENSSL_PREFIX=
#OPENH264_PREFIX=
OPUS_PREFIX=
while [ "$#" -gt 0 ]; do
    case $1 in
        --with-openssl)
            if [ "$#" -gt 1 ]; then
                OPENSSL_PREFIX=$(python -c "import os,sys; print os.path.realpath(sys.argv[1])" "$2")
                shift 2
                continue
            else
                echo 'ERROR: Must specify a non-empty "--with-openssl PREFIX" argument.' >&2
                exit 1
            fi
            ;;
#        --with-openh264)
#            if [ "$#" -gt 1 ]; then
#                OPENH264_PREFIX=$(python -c "import os,sys; print os.path.realpath(sys.argv[1])" "$2")
#                shift 2
#                continue
#            else
#                echo 'ERROR: Must specify a non-empty "--with-openh264 PREFIX" argument.' >&2
#                exit 1
#            fi
#            ;;
        --with-opus)
            if [ "$#" -gt 1 ]; then
                OPUS_PREFIX=$(python -c "import os,sys; print os.path.realpath(sys.argv[1])" "$2")
                shift 2
                continue
            else
                echo 'ERROR: Must specify a non-empty "--with-opus PREFIX" argument.' >&2
                exit 1
            fi
            ;;
    esac

    shift
done

function config_site() {
    SOURCE_DIR=$1
    PJSIP_CONFIG_PATH="${SOURCE_DIR}/pjlib/include/pj/config_site.h"
    HAS_VIDEO=1

    echo "Creating config_site.h ..."

    if [ -f "${PJSIP_CONFIG_PATH}" ]; then
        rm "${PJSIP_CONFIG_PATH}"
    fi

#	echo "#define PJ_CONFIG_IPHONE 1" >> "${PJSIP_CONFIG_PATH}"
    echo "#define PJ_HAS_IPV6 1" >> "${PJSIP_CONFIG_PATH}" # Enable IPV6
#    if [[ ${OPENH264_PREFIX} ]]; then
#		echo "#define PJMEDIA_HAS_OPENH264_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
#        HAS_VIDEO=1
#    fi
    if [[ ${HAS_VIDEO} ]]; then
		echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
		echo "#define PJMEDIA_HAS_VID_TOOLBOX_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
#       echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
#       echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL_ES 1" >> "${PJSIP_CONFIG_PATH}"
#       echo "#define PJMEDIA_VIDEO_DEV_HAS_IOS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
#       echo "#include <OpenGLES/ES3/glext.h>" >> "${PJSIP_CONFIG_PATH}"
    fi
    echo "#include <pj/config_site_sample.h>" >> "${PJSIP_CONFIG_PATH}"
}

function configure () {
	TYPE=$1
	ARCH=$2
#	PLATFORM=$3
#	SDK_VERSION=$4
#	DEPLOYMENT_VERSION=$5
	LOG=$3

	HAS_VIDEO=1
	PJSIP_CONFIG_PATH="${PJSIP_DIR}/pjlib/include/pj/config_site.h"
	CONFIGURE=

	echo "Creating config_site.h ..."

	if [ -f "${PJSIP_CONFIG_PATH}" ]; then
		rm "${PJSIP_CONFIG_PATH}"
	fi


	if [ "$TYPE" == "macos" ]; then
		# OSX
		if [[ ${HAS_VIDEO} ]]; then
			echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
			echo "#define PJMEDIA_HAS_VID_TOOLBOX_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
		fi
	elif [ "$TYPE" == "ios" ]; then
		# iOS
		echo "#define PJ_CONFIG_IPHONE 1" >> "${PJSIP_CONFIG_PATH}"
		echo "#define PJ_IPHONE_OS_HAS_MULTITASKING_SUPPORT 0" >> "${PJSIP_CONFIG_PATH}" # for iOS 9+
		if [[ ${HAS_VIDEO} ]]; then
			echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
#	??		echo "#define PJMEDIA_HAS_VID_TOOLBOX_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
			echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
			echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL_ES 1" >> "${PJSIP_CONFIG_PATH}"
			echo "#define PJMEDIA_VIDEO_DEV_HAS_IOS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
			echo "#include <OpenGLES/ES3/glext.h>" >> "${PJSIP_CONFIG_PATH}"
		fi
	fi

	echo "#define PJ_HAS_IPV6 1" >> "${PJSIP_CONFIG_PATH}" # Enable IPV6
	echo "#include <pj/config_site_sample.h>" >> "${PJSIP_CONFIG_PATH}" # Include example config

	if [ "$TYPE" == "macos" ]; then
		# OSX
		export DEVPATH="${OSX_PLATFORM}/Developer"
	elif [ "$TYPE" == "ios" ]; then
		# iOS
		if [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "i386" ]; then
			export DEVPATH="${IPHONESIMULATOR_PLATFORM}/Developer"
			export CFLAGS="${CFLAGS} -O2 -m32 -mios-simulator-version-min=${IPHONEOS_DEPLOYMENT_VERSION}"
			export LDFLAGS="${LDFLAGS} -O2 -m32 -mios-simulator-version-min=${IPHONEOS_DEPLOYMENT_VERSION}"
		else
			export MIN_IOS="-miphoneos-version-min=${IPHONEOS_DEPLOYMENT_VERSION}"
			export DEVPATH="${IPHONEOS_PLATFORM}/Developer"
			export CFLAGS="${CFLAGS}"
			export LDFLAGS="${LDFLAGS}"
		fi
	fi

	# configure
	if [ "$TYPE" == "ios" ]; then
		# iOS
		CONFIGURE="./configure-iphone"
	elif [ "$TYPE" == "macos" ]; then
		# macOS
		CONFIGURE="./configure"
	fi


	if [[ ${OPENSSL_PREFIX} ]]; then
		CONFIGURE="${CONFIGURE} --with-ssl=${OPENSSL_PREFIX}"
	fi
	if [[ ${OPUS_PREFIX} ]]; then
		CONFIGURE="${CONFIGURE} --with-opus=${OPUS_PREFIX}"
	fi

	# flags
	if [[ ! ${CFLAGS} ]]; then
		export CFLAGS=
	fi
	if [[ ! ${LDFLAGS} ]]; then
		export LDFLAGS=
	fi
	if [[ ${OPENSSL_PREFIX} ]]; then
		export CFLAGS="${CFLAGS} -I${OPENSSL_PREFIX}/include"
		if [ "$TYPE" == "ios" ]; then
			export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib/ios"
		elif [ "$TYPE" == "macos" ]; then
			export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib/macos"
		fi
	fi
	export LDFLAGS="${LDFLAGS} -lstdc++"


	echo "[DEBUG] distclean..."
	make distclean > ${LOG} 2>&1
	echo "[DEBUG] configuring..."
	ARCH="-arch ${ARCH}" ${CONFIGURE} >> ${LOG} 2>&1
	echo "Done configuring" >> ${LOG} 2>&1
}

function build () {
	ARCH=$1
	SDK=$2
	TYPE=$3

	pushd . > /dev/null
	cd ${PJSIP_DIR}

	LOG=${BASE_DIR}/${TYPE}-${ARCH}.log
#	export BUILD_TOOLS="${DEVELOPER}"
#	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"

#	mkdir -p "lib-${TYPE}"

#	if [ "$TYPE" == "ios" ]; then
#		# IOS
#		if [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "i386" ]; then
##			configure "iPhoneSimulator" $ARCH $LOG
#			configure $TYPE $ARCH $LOG
#		else
##			configure "iPhoneOS" $ARCH $LOG
#			configure $TYPE $ARCH $LOG
#		fi
#	elif [ "$TYPE" == "macos" ]; then
#		# OSX
##		configure "MacOSX" $ARCH $LOG
#		configure $TYPE $ARCH $LOG
#	fi

	configure $TYPE $ARCH $LOG

	echo "Building for ${TYPE} ${ARCH}..."

#	clean_libs ${ARCH}
	make dep >> ${LOG} 2>&1
	make clean >> ${LOG}
	make lib >> ${LOG} 2>&1

	copy_libs ${ARCH} ${TYPE}
}


function clean_libs () {
    ARCH=${1}
	TYPE=${2}

    for SRC_DIR in ${LIB_PATHS[*]}; do
        DIR="${PJSIP_DIR}/${SRC_DIR}"
        if [ -d "${DIR}" ]; then
            rm -rf "${DIR}"/*
        fi

        DIR="${PJSIP_DIR}/${SRC_DIR}-${ARCH}"
        if [ -d "${DIR}" ]; then
            rm -rf "${DIR}"
        fi
    done
}

function copy_libs () {
    ARCH=${1}
	TYPE=${2}

    for SRC_DIR in ${LIB_PATHS[*]}; do
        SRC_DIR="${PJSIP_DIR}/${SRC_DIR}"
		DST_DIR="${SRC_DIR}-${TYPE}-${ARCH}"
        if [ -d "${DST_DIR}" ]; then
            rm -rf "${DST_DIR}"
        fi
        cp -R "${SRC_DIR}" "${DST_DIR}"
        rm -rf "${SRC_DIR}"/* # delete files because this directory will be used for the final lipo output
    done
}

function _build() {
	pushd . > /dev/null
	cd ${PJSIP_DIR}

	ARCH=$1
	LOG=${BASE_DIR}/${ARCH}.log

	# configure
	CONFIGURE="./configure"
	if [[ ${OPENSSL_PREFIX} ]]; then
		CONFIGURE="${CONFIGURE} --with-ssl=${OPENSSL_PREFIX}"
	fi
	if [[ ${OPUS_PREFIX} ]]; then
		CONFIGURE="${CONFIGURE} --with-opus=${OPUS_PREFIX}"
	fi
	# flags
	if [[ ! ${CFLAGS} ]]; then
		export CFLAGS=
	fi
	if [[ ! ${LDFLAGS} ]]; then
		export LDFLAGS=
	fi
	if [[ ${OPENSSL_PREFIX} ]]; then
		export CFLAGS="${CFLAGS} -I${OPENSSL_PREFIX}/include"
		export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib"
	fi
	export LDFLAGS="${LDFLAGS} -lstdc++"

	echo "Building for ${ARCH}..."

	clean_libs ${ARCH}

	make distclean > ${LOG} 2>&1
	ARCH="-arch ${ARCH}" ${CONFIGURE} >> ${LOG} 2>&1
	make dep >> ${LOG} 2>&1
	make clean >> ${LOG}
	make lib >> ${LOG} 2>&1

	copy_libs ${ARCH}
}

function i386() {
#    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
#    export CFLAGS="-O2 -m32 -mios-simulator-version-min=8.0"
#    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=8.0"
    _build "i386"
}
function x86_64() {
#    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
#    export CFLAGS="-O2 -m32 -mios-simulator-version-min=8.0"
#    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=8.0"
    _build "x86_64"
}


function lipo() {
    TMP=`mktemp -t lipo`
    echo "Lipo libs... (${TMP})"

    for LIB_DIR in ${LIB_PATHS[*]}; do # loop over libs
        DST_DIR="${PJSIP_DIR}/${LIB_DIR}"

        # use the first architecture to find all libraries
        PATTERN_DIR="${DST_DIR}-$1"
        for PATTERN_FILE in `ls -l1 "${PATTERN_DIR}"`; do
            OPTIONS=""

            # loop over all architectures and collect the current library
            for ARCH in "$@"; do
                FILE="${DST_DIR}-${ARCH}/${PATTERN_FILE/-$1-/-${ARCH}-}"
                if [ -e "${FILE}" ]; then
                    OPTIONS="$OPTIONS -arch ${ARCH} ${FILE}"
                fi
            done

            if [ "$OPTIONS" != "" ]; then
                OUTPUT_PREFIX=$(dirname "${DST_DIR}")
                OUTPUT="${OUTPUT_PREFIX}/lib/${PATTERN_FILE/-$1-/-}"

                OPTIONS="${OPTIONS} -create -output ${OUTPUT}"
                echo "$OPTIONS" >> "${TMP}"
            fi
        done
    done

    while read LINE; do
        xcrun -sdk macosx lipo ${LINE}
    done < "${TMP}"
}

download "${PJSIP_URL}" "${PJSIP_DIR}"
#config_site "${PJSIP_DIR}"


build "i386" "${IPHONESIMULATOR_SDK}" "ios"
build "x86_64" "${IPHONESIMULATOR_SDK}" "ios"
build "armv7" "${IPHONEOS_SDK}" "ios"
build "armv7s" "${IPHONEOS_SDK}" "ios"
build "arm64" "${IPHONEOS_SDK}" "ios"

build "i386" "${OSX_SDK}" "macos"
build "x86_64" "${OSX_SDK}" "macos"

#lipo x86_64 i386
