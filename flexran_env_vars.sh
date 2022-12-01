# FlexRAN root according on how we set up this build
flexranPath=/opt/flexran

# FlexRAN env
export RTE_SDK=$flexranPath/dpdk-21.11
export RTE_TARGET=x86_64-native-linux-icc
export WIRELESS_SDK_TARGET_ISA=avx512
export RPE_DIR=${flexranPath}/libs/ferrybridge
export ROE_DIR=${flexranPath}/libs/roe
export XRAN_DIR=${flexranPath}/xran
export WIRELESS_SDK_TOOLCHAIN=icc
export DIR_WIRELESS_SDK_ROOT=${flexranPath}/sdk
export DIR_WIRELESS_TEST_5G=${flexranPath}/tests/nr5g
export SDK_BUILD=build-${WIRELESS_SDK_TARGET_ISA}-${WIRELESS_SDK_TOOLCHAIN}
export DIR_WIRELESS_SDK=${DIR_WIRELESS_SDK_ROOT}/${SDK_BUILD}
export FLEXRAN_SDK=${DIR_WIRELESS_SDK}/install
export DIR_WIRELESS_TABLE_5G=${flexranPath}/bin/nr5g/gnb/l1/table
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${flexranPath}/icc_libs:${flexranPath}/wls_mod:${flexranPath}/libs/cpa/bin

# Crucible selective XRAN tests
export ORU_DIR=${flexranPath}/bin/nr5g/gnb/l1/orancfg/sub3_mu0_20mhz_4x4/oru

