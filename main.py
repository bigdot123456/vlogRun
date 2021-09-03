# This is a sample Python script.

# Press Shift+F10 to execute it or replace it with your code.
# Press Double Shift to search everywhere for classes, files, tool windows, actions, and settings.
import os
import re
import subprocess
# out_bytes = subprocess.check_output(['netstat','-a'])
# out_bytes = subprocess.check_output('grep python j wc > out', shell=True)
import time

execFile = "vlog-chen.exe"
execFile = "/eda/mentor/questasim/bin/vlog"


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

                print(f"{num}: Processing {filename} !")
                num = num + 1
                # fs = f1.find('sv_', 1, 3)
                # fs = f1.find('sv_')
                # if fs == -1:
                cmd = vlogRun(fpathe, f1)
                cmdList.append(cmd + '\n')
                vlogClean(fpathe, f1)

            if filename.endswith('vhd'):  # 判断是否是"xxx"结尾

                print(f"{num}: Processing {filename} !")
                num = num + 1
                # fs = f1.find('sv_', 1, 3)
                # fs = f1.find('sv_')
                # if fs == -1:
                cmd = vhdlRun(fpathe, f1)
                cmdList.append(cmd + '\n')
                vlogClean(fpathe, f1)

    with open("./cmdList.sh", 'w') as fw:
        fw.writelines(cmdList)


def vlogRun(fpathe, fname):
    f0 = os.path.join(fpathe, fname)
    f1 = os.path.join(fpathe, f'{fname}.vlog')
    if os.path.exists(f1):
        os.remove(f1)
    cmd = f"{execFile} {f0} > {f1}"
    print(f"decrypting {f0}:  {cmd}")
    try:
        os.system(cmd)  # should wait it finish
        # subprocess.check_output(['netstat', '-a'])
        # out=subprocess.check_output(cmd)
    except:
        print(f"Cant execute cmd:{cmd}\nRecover file to original!")

    if os.path.exists(f1) and os.path.getsize(f1) == 0:
        print(f"Decrypt failure with {cmd}, remove TMP files!")
        os.remove(f1)

    while not os.path.exists(f1):
        time.sleep(1)

    return cmd


def vhdlRun(fpathe, fname):
    f0 = os.path.join(fpathe, fname)
    f1 = os.path.join(fpathe, f'{fname}.vlog')
    f2 = os.path.join(fpathe, f'{fname}.v2v')
    if os.path.exists(f1):
        os.remove(f1)
    if os.path.exists(f2):
        os.remove(f2)

    with open(f0, 'r') as fp_in:
        #a = fp_in.readlines()
        a = fp_in.read()
        if len(a) == 0:
            print(f"{f0} is null, Please check command!")
            return
        # list can't use replace,but string is ok
        # a.replace('`protect', '`pragma protect')
        t = a.replace('`protect', '`pragma protect')
        b = f'module {fname}();\n'
        c = 'endmodule'
        with open(f2, 'w') as fp_out:
            fp_out.writelines(b)
            fp_out.writelines(t)
            fp_out.writelines(c)

    cmd = f"{execFile} {f2} > {f1}"
    print(f"decrypting {f0} via {cmd}")
    try:
        os.system(cmd)  # should wait it finish
    except:
        print(f"Cant execute cmd:{cmd}\nRecover file to original!")

    if os.path.exists(f1) and os.path.getsize(f1) == 0:
        print(f"Decrypt failure with {cmd}, remove TMP files!")
        os.remove(f1)

    return cmd


def vlogClean(fpathe, fname):
    f0 = os.path.join(fpathe, f'{fname}.vlog')
    f1 = os.path.join(fpathe, f'{fname}.dec')

    try:
        with open(f0, 'r') as fp_in:
            a = fp_in.readlines()
            if len(a) == 0:
                print(f"{f0} is null, Please check command!")
                return

            a0 = a[0]
            a1 = a[-1]
            # use index should add try and except sentence
            #            if a0.index('QuestaSim-64') > -1 and a1.index('Warnings') > -1:
            if a0.find('QuestaSim') > -1 and a1.find('Warnings') > -1:
                with open(f1, 'w') as fp_out:
                    w_line = a[-1]
                    w_line0 = re.split(r'[\s\,\;]+', w_line)
                    w_line1 = int(w_line0[3]) + int(w_line0[1]) + 3
                    print(f"{f0} will cut {w_line1} lines!")

                    b = a[3:-1 - w_line1]
                    fp_out.writelines(b)
            else:
                print(f'{f0} is not valid decrypt files!')

    except IOError as err:
        print(f"File Error {str(err)}: {f0} doesn't exists!")


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    VlogIterate('./')
