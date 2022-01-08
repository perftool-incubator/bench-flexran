#!/bin/bash
declare -a CfgFiles=("/opt/flexran/bin/nr5g/gnb/l1/phycfg_timer.xml" "/opt/flexran/bin/nr5g/gnb/l1/phycfg_radio_sub6.xml")

for val in ${CfgFiles[@]}; do
  sed -i 's#<dpdkBasebandFecMode>.*</dpdkBasebandFecMode>#<dpdkBasebandFecMode>1</dpdkBasebandFecMode>#' $val
  sed -i "s#<dpdkBasebandDevice>.*</dpdkBasebandDevice>#<dpdkBasebandDevice>${PCIDEVICE_INTEL_COM_INTEL_FEC_5G}</dpdkBasebandDevice>#" $val
done

