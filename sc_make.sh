#!/bin/bash

# This script is used to automate the build process of Sonic for Marvell platforms
# NOTE: Change CACHE_DIR and ARTIFACTS_DIR as per your requirement.

# arguments
INPUT=$@

# Script-debug/trace option "-e"
#set -e

print_usage()
{
    echo "Usage:"
    echo ""
    echo " $0"
    echo "   [-t <type>]"
    echo "   [-T <target>]"
    echo ""
    echo "    -t : Build type"
    echo "    -T : Build target"
echo """
Example:
./sc_make.sh -t all 
./sc_make.sh -t image
./sc_make.sh -T docker-teamd.gz
./sc_make.sh -T debs/bookworm/tkmib_5.9.3+dfsg-2_all.deb
"""
}

parse_arguments()
{
    while [[ $# -gt 0 ]]; do
        case $1 in
	    -t|--type)
                BUILD_TYPE="$2"
                shift # past argument
                shift # past value
                ;;
	    -T|--target)
                BUILD_TARGET="$2"
                shift # past argument
                shift # past value
                ;;
            -h|--help)
                print_usage
                exit 1
                ;;
            *)
                echo "ERROR: Unknown option '$1'"
                print_usage
                exit 1
                ;;
        esac
    done
}

patch_ws()
{
	CWD=`pwd`
	cat series_sercomm-prestera_arm64 | grep -v -E '^#|^$' | grep -v sonic-buildimage | while read -r line
 do
        patch=`echo $line | cut -f 1 -d'|'`
        dir=`echo $line | cut -f 2 -d'|'`
        pushd ${dir}
        git am $CWD/patches/${patch}
        ret=$?
        if [ $ret -ne 0 ]; then
        ((err_cnt++))
                if [ "$PATCH_ERR_SKIP" == "" ]; then
                        echo "PATCH ERROR: Failed to apply submodule $CWD/patches/${patch}, abort"
                        return $ret
                fi
                echo "PATCH ERROR: Failed to apply submodule $CWD/patches/${patch}, skeep and continue"
                git am --skip
        fi
        popd
 done

 cat series_sercomm-prestera_arm64 | grep -v -E '^#|^$' | grep sonic-buildimage | cut -f 1 -d'|' | while read -r patch_file
 do
        echo $patch_file
        git am patches/$patch_file
        ret=$?
        if [ $ret -ne 0 ]; then
        ((err_cnt++))
                if [ "$PATCH_ERR_SKIP" == "" ]; then
                        echo "PATCH ERROR: Failed to apply sonicbuildimage patches/$patch_file, abort"
                        return $ret
                fi
                echo "PATCH ERROR: Failed to apply sonicbuildimage patches/$patch_file, skeep and continue"
                git am --skip
        fi
 done

 echo > patch_done
}

build_init()
{
    local startTime=$SECONDS
    echo "make init" >> build_cmd.txt
    make init

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
}

build_configure()
{
    local startTime=$SECONDS

    echo "make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64" >> build_cmd.txt
    make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
}

build_image()
{
    local startTime=$SECONDS

    echo "make SONIC_BUILD_JOBS=4 target/sonic-marvell-arm64.bin" >> build_cmd.txt
    make SONIC_BUILD_JOBS=4 target/sonic-marvell-arm64.bin 

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
}

build_target()
{
    local startTime=$SECONDS

    TARGET=target/${BUILD_TARGET}
    echo "make SONIC_BUILD_JOBS=4 ${TARGET}" >> build_cmd.txt
    make SONIC_BUILD_JOBS=4 ${TARGET}

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
}

build_ws()
{
    local startTime=$SECONDS

    echo "make init" >> build_cmd.txt
    make init

    echo "make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64" >> build_cmd.txt
    make configure PLATFORM=marvell-arm64 PLATFORM_ARCH=arm64

    echo "make SONIC_BUILD_JOBS=4 target/sonic-marvell-arm64.bin" >> build_cmd.txt
    make SONIC_BUILD_JOBS=4 target/sonic-marvell-arm64.bin

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
}

main()
{
    parse_arguments $@

    if [ ! -f patch_done ]; then
    	patch_ws
    fi

    if [ "${BUILD_TYPE}" == "init" ]; then
	    build_init
    fi

    if [ "${BUILD_TYPE}" == "configure" ]; then
	    build_configure
    fi

    if [ "${BUILD_TYPE}" == "image" ]; then
            build_image
    fi

    if [ "${BUILD_TYPE}" == "all" ]; then
    	    build_ws
    fi

    if [ -n "${BUILD_TARGET}" ]; then
            build_target
    fi
    set +x


    echo -e "\n\n Build Successful \n\n"
    exit 0
}

main $@
