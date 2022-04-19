#!/usr/bin/python3
# This is based on https://gist.github.com/amadorpahim/3062277
# This is adapted from  https://github.com/redhat-eets/flexran/blob/ci/automation/pod/autotest.py

import os,re,copy,sys,getopt,yaml
import xml.etree.ElementTree as ET
from cpu import CpuResource

from process_testfile import ProcessTestfile

procstatus = '/proc/self/status'

from log import logger 
from pprint import pprint
import subprocess

class Setting:

    @classmethod
    def update_xran_cfg_files(cls, oru_cfgfile: str, vfs_pci, cpursc: CpuResource):
        print ("Updating XRAN %s:" % oru_cfgfile);
        # Step 1: fix-up DU 2 VF PCIs
        #<PciBusAddoRu0Vf0>0000:1a:02.0</PciBusAddoRu0Vf0>
        #<PciBusAddoRu0Vf1>0000:1a:02.1</PciBusAddoRu0Vf1>
        pci_addr=vfs_pci.split(",")

        spec= "s#<PciBusAddoRu0Vf0>.*</PciBusAddoRu0Vf0>#<PciBusAddoRu0Vf0>PCI_ADDR</PciBusAddoRu0Vf0>#"  
        result = re.sub("PCI_ADDR", str(pci_addr[0]), spec)
        subprocess.call(["sed", "-i", result, oru_cfgfile])

        spec= "s#<PciBusAddoRu0Vf1>.*</PciBusAddoRu0Vf1>#<PciBusAddoRu0Vf1>PCI_ADDR</PciBusAddoRu0Vf1>#"  
        result = re.sub("PCI_ADDR", str(pci_addr[1]), spec)
        subprocess.call(["sed", "-i", result, oru_cfgfile])

        # Step 2: fix-up RU 2 VF MACs
        # Crucible 09-ru_sriov.sh hardcode the below MACs. So no need to change
        # <oRuRem0Mac0>00:11:22:33:00:01</oRuRem0Mac0>
        # <oRuRem0Mac1>00:11:22:33:00:11</oRuRem0Mac1>

        # step 3: Alloc a CPU for xRANThread
        # <xRANThread>18, 96, 0</xRANThread>
        cpu = cpursc.allocate_whole_core()
        spec= "s#<xRANThread>.*,.*,.*</xRANThread>#<xRANThread>CPU_NUM, 6, 0</xRANThread>#"  
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, oru_cfgfile])
        
        # step 4: Alloc a CPU for xRANWorker, but fixup in cpu_mask
        # <xRANWorker>0x80000, 96, 0</xRANWorker>
        core_mask = cpursc.allocate_siblings_mask(1)
        logger.debug("mask=" + str(core_mask))
        spec= "s#<xRANWorker>.*,.*,.*</xRANWorker>#<xRANWorker>CPU_MASK, 6, 0</xRANWorker>#"  
        result = re.sub("CPU_MASK", str(core_mask), spec)
        subprocess.call(["sed", "-i", result, oru_cfgfile])

    @classmethod
    def update_cfg_files(cls, l1_cfg_file: str, testmac_cfg_file: str, cpursc: CpuResource):
        print ("Updating %s %s:" % (l1_cfg_file, testmac_cfg_file));
        
        # First in list is the HK_CPUS, Use whole core for systemThreads abd RunThread
        cpu = cpursc.allocate_whole_core()
        spec= "s#<systemThread>.*,.*,.*</systemThread>#<systemThread>CPU_NUM, 0, 0</systemThread>#"  
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, l1_cfg_file])

        spec = "s#<systemThread>.*,.*,.*</systemThread>#<systemThread>CPU_NUM, 0, 0</systemThread>#"
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, testmac_cfg_file])

        spec = "s#<runThread>.*,.*,.*</runThread>#<runThread>CPU_NUM, 89, 0</runThread>#"
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, testmac_cfg_file])
            
        # Use second CPU
        cpu = cpursc.allocateone()
        spec = "s#<timerThread>.*,.*,.*</timerThread>#<timerThread>CPU_NUM, 6, 0</timerThread>#"
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, l1_cfg_file])

        spec = "s#<radioDpdkMaster>.*,.*,.*</radioDpdkMaster>#<radioDpdkMaster>CPU_NUM, 99, 0</radioDpdkMaster>#" 
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, l1_cfg_file])

        # Use third CPU
        cpu = cpursc.allocateone()
        spec = "s#<wlsRxThread>.*,.*,.*</wlsRxThread>#<wlsRxThread>CPU_NUM, 90, 0</wlsRxThread>#"
        result = re.sub("CPU_NUM", str(cpu), spec)
        subprocess.call(["sed", "-i", result, testmac_cfg_file])

    # Call the update_tesfile function of the ProcessTestfile class (in
    # process_testfile.py).
    @classmethod
    def update_testfile(cls, rsc, testfile, phystart_quick=False):
        ProcessTestfile.update_testfile(rsc, testfile, phystart_quick)

import argparse
def main(name, argv):
    nosibling = False
    nohkcpus = False
    phystart = None
    testfile = None
    l1_cfgfile = None
    testmac_cfgfile = None
    oru_cfgfile = None
    vfs_pci = []
    xran = False
    print (sys.argv[1:]);

    parser = argparse.ArgumentParser()
    parser.add_argument('--testfile', type=str, required=False)
    parser.add_argument('--l1_cfgfile', type=str, required=False)
    parser.add_argument('--testmac_cfgfile', type=str, required=False)
    parser.add_argument('--oru_cfgfile', type=str, required=False)
    parser.add_argument('--oru_vfs_pci', type=str, required=False)
    # https://intellipaat.com/community/4618/argparse-module-how-to-add-option-without-any-argument
    parser.add_argument('--nosibling', action='store_true')
    parser.add_argument('--phystart', action='store_true')
    parser.add_argument('--nohkcpus', action='store_true')
    parser.add_argument('--xran', action='store_true')

    arg = parser.parse_args()
    if arg.testfile:
        testfile = arg.testfile
        logger.debug("--testfile= " + str(testfile))
    if arg.l1_cfgfile:
        l1_cfgfile = arg.l1_cfgfile
        logger.debug("--l1_cfgfile= " + str(l1_cfgfile))
    if arg.testmac_cfgfile:
        testmac_cfgfile = arg.testmac_cfgfile
        logger.debug("--testmac_cfgfile= " + str(testmac_cfgfile))
    if arg.oru_cfgfile:
        oru_cfgfile = arg.oru_cfgfile
        logger.debug("--oru_cfgfile= " + oru_cfgfile)
    if arg.oru_vfs_pci:
        vfs_pci = arg.oru_vfs_pci
        logger.debug("--oru_vfs_pci= " + str(vfs_pci))
    if arg.nosibling:
        nosibling = True
        logger.debug("--nosibling")
    if arg.phystart:
        phystart = True
        logger.debug("--phystart= " + str(phystart))
    if arg.nohkcpus:
        nohkcpus = True
    if arg.xran:
        xran = True

    # Note - Crucible does not use '/proc/self/status'
    #   status_content = open(procstatus).read().rstrip('\n')
    #   cpursc = CpuResource(status_content, nosibling)
    # crucible use HK_CPUS and WORKLOAD_CPUS
    cpus_str_list = os.getenv('WORKLOAD_CPUS').split(",")
    if nohkcpus == False:
        # Add HK_CPUS in front so systemThread(s) use HK_CPUS first per best-practice
        cpus_str_list = os.getenv('HK_CPUS').split(",") + cpus_str_list

    integer_list = list(map(int, cpus_str_list))
    cpursc = CpuResource("", nosibling, integer_list)
    if nosibling == True:
        logger.debug("Remove siblings")
        cpursc.remove_siblings()

    # Note: update_cfg_files must always be called in order to remove any common cpus
    # from cpursc before cpursc is used by update_testfile below.

    Setting.update_cfg_files(l1_cfgfile, testmac_cfgfile, cpursc)
    logger.debug("after cfg_files, cpus available: " + str(cpursc.available))

    # ORU config
    if oru_cfgfile is not None:
        logger.debug("HN pre oru_cfg=" + str(oru_cfgfile))
        logger.debug("HN pre vfs_pci=" + str(vfs_pci))
        Setting.update_xran_cfg_files(oru_cfgfile, vfs_pci, cpursc)
            

    if testfile is not None:
        # NOTE: QUICK PHYSTART NOTED BY TRUE, CHANGE FOR REAL TESTS.
        Setting.update_testfile(cpursc, testfile, phystart)
        print('Test file updated: %s' % testfile)


if __name__ == "__main__":
     main(sys.argv[0], sys.argv[1:])
