# This is a sample Python script.

# Press Shift+F10 to execute it or replace it with your code.
# Press Double Shift to search everywhere for classes, files, tool windows, actions, and settings.
import os
import re
from SplitSV import *
from cleanVlog import *
# can use import SplitSV; then we should run with SplitSV.func()

# import subprocess
# out_bytes = subprocess.check_output(['netstat','-a'])
# out_bytes = subprocess.check_output('grep python j wc > out', shell=True)
#import time

execFile = "vlog-chen.exe"
execFile = "/eda/mentor/questasim/bin/vlog"

matchPattern = re.compile(r"^[*]+ Error:|^[*]+ Warning:")


def VlogIterate(PathName):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, Go {PathName}!\n')  # Press Ctrl+F8 to toggle the breakpoint.

    # all = []
    num = 1
    cmdList = []
    for fpathe, dirs, fs in os.walk(PathName):  # os.walk是获取所有的目录
        for f1 in fs:
            filename = os.path.join(fpathe, f1)
            if filename.endswith('sv') | filename.endswith('v'):  # 判断是否是"xxx"结尾

                print(f"{num}: Processing vlog {filename} !")
                num = num + 1
                # fs = f1.find('sv_', 1, 3)
                # fs = f1.find('sv_')
                # if fs == -1:
                cmd = vlogRun(fpathe, f1)
                if cmd != "":
                    cmdList.append(cmd + '\n')
                    vlogClean(fpathe, f1)
                    vlogSplit(fpathe, f1)

            if filename.endswith('vhd'):  # 判断是否是"xxx"结尾

                print(f"{num}: Processing vcom {filename} !")
                num = num + 1
                # fs = f1.find('sv_', 1, 3)
                # fs = f1.find('sv_')
                # if fs == -1:
                cmd = vhdlRun(fpathe, f1)
                if cmd != "":
                    cmdList.append(cmd + '\n')
                    vlogClean(fpathe, f1)

    with open("./cmdList.sh", 'w') as fw:
        fw.writelines(cmdList)


def vlogRun(fpathe, fname):
    f0 = os.path.join(fpathe, fname)
    f1 = os.path.join(fpathe, f'{fname}.vlog')
    if os.path.exists(f1):
        os.remove(f1)

    with open(f0, 'r') as fp_in:
        # a = fp_in.readlines()
        a = fp_in.read()
        if len(a) == 0:
            print(f"{f0} is null, Please check command!")
            return ""
        if a.find('`pragma protect') == -1:
            print(f"{f0} is not encrypted vlog, omit!")
            return ""

    cmd = f"{execFile} -sv -sv17compat {f0} > {f1}"
    print(f"vlog decrypting {f0}:  {cmd}")
    try:
        os.system(cmd)  # should wait it finish
        # subprocess.check_output(['netstat', '-a'])
        # out=subprocess.check_output(cmd)
    except:
        print(f"Cant execute cmd:{cmd}\nRecover file to original!")

    if os.path.exists(f1) and os.path.getsize(f1) == 0:
        print(f"Decrypt failure with {cmd}, remove TMP files!")
        os.remove(f1)

    # while not os.path.exists(f1):
    #     time.sleep(1)

    return cmd


def vhdlRun(fpathe, fname):
    f0 = os.path.join(fpathe, fname)
    f1 = os.path.join(fpathe, f'{fname}.vlog')
    f2 = os.path.join(fpathe, f'{fname}.vcom')
    if os.path.exists(f1):
        os.remove(f1)
    if os.path.exists(f2):
        os.remove(f2)

    with open(f0, 'r') as fp_in:
        # a = fp_in.readlines()
        a = fp_in.read()
        if len(a) == 0:
            print(f"{f0} is null, Please check command!")
            return ""
        if a.find('`protect') == -1:
            print(f"{f0} is not encrypted vhdl, omit!")
            return ""
        # list can't use replace,but string is ok
        # a.replace('`protect', '`pragma protect')
        t = a.replace('`protect', '`pragma protect')
        basename = os.path.basename(f0)
        file_name = os.path.splitext(basename)[0]
        # not contain extend file name
        b = f'module {file_name}();\n'
        c = 'endmodule'
        with open(f2, 'w') as fp_out:
            fp_out.writelines(b)
            fp_out.writelines(t)
            fp_out.writelines(c)

    cmd = f"{execFile} {f2} > {f1}"
    print(f"vhdl decrypting {f0} via {cmd}")
    try:
        os.system(cmd)  # should wait it finish
    except:
        print(f"Cant execute cmd:{cmd}\nRecover file to original!")

    if os.path.exists(f1) and os.path.getsize(f1) == 0:
        print(f"Decrypt failure with {cmd}, remove TMP files!")
        os.remove(f1)

    return cmd

# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    VlogIterate('./')
# vlogClean('./', 'can_v5_0_rfs.vhd')
