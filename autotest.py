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
    def update_cfg_files(cls, cfg: str, cpursc: CpuResource):
        
        l1_cfg_file = os.getenv('L1_CFG_FILE')
        testmac_cfg_file = os.getenv('TESTMAC_CFG_FILE')

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

def main(name, argv):
    logger.info("Enter: ")
    nosibling = False
    nohkcpus = False
    phystart = False
    testfile = None
    helpstr = name + " --testfile=<testfile path>"\
                     " --nosibling"\
                     " --nohkcpus"\
                     " --phystart">\
                     "\n"
    try:
        opts, args = getopt.getopt(argv,"h",["testfile=", "nosibling", "phystart", "nohkcpus"])
    except getopt.GetoptError:
        logger.info("error")
        print(helpstr)
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-h':
            print(helpstr)
            sys.exit()
        elif opt in ("--testfile"):
            testfile = arg
        elif opt in ("--nosibling"):
            nosibling = True
        elif opt in ("--phystart"):
            phystart = True
        elif opt in ("--nohkcpus"):
            nohkcpus = True
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
    Setting.update_cfg_files(None, cpursc)
    logger.debug("after cfg_files, cpus available: " + str(cpursc.available))

    if testfile is not None:
        # NOTE: QUICK PHYSTART NOTED BY TRUE, CHANGE FOR REAL TESTS.
        Setting.update_testfile(cpursc, testfile, phystart)
        print('Test file updated: %s' % testfile)

if __name__ == "__main__":
     main(sys.argv[0], sys.argv[1:])
