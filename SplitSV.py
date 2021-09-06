#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) qinghua 2021 ***
"""
"This is function description docstring."
”””Function is aimed for systemverilog and vhdl file split.  ”””
"""
# 把 import 语句放在文件头部,在模块 docstring 之后,在模块全局变量或全局常量之前
import os
import sys
import time
import re

m0Pattern = re.compile(r"^[\s]*module[\s]+([A-Za-z0-9_]{1,})[\s]*")
m1Pattern = re.compile(r"[\s]*endmodule")


def vlogSplit(fpathe, fname):
    f0 = os.path.join(fpathe, f'{fname}.dec')
    basename = os.path.basename(f0)
    subdirname = os.path.splitext(fname)[0]

    try:
        SubPath = os.path.join(fpathe, subdirname)
        # 判断是否已经存在该目录
        if not os.path.exists(SubPath):
            # 目录不存在，进行创建操作
            os.makedirs(SubPath)  # 使用os.makedirs()方法创建多层目录
            print("Add Split directory" + SubPath)
        else:
            print(f"{SubPath} directory exists")
    except BaseException as msg:
        print(f"Creating {SubPath} directory Failure!")

    with open(f0, 'r') as fp_in:
        # if os.path.exists(f0) and os.path.getsize(f1) == 0:
        #     print(f"{f0} is null, Please check command!")
        #     return
        a = fp_in.readlines()
        if len(a) == 0:
            print(f"{f0} is null, Please check command!")
            return

        t = []
        for b in a:
            t.append(b)
            x = m0Pattern.search(b)
            if x:
                p = m0Pattern.split(b)
                mName = p[1]
                f1 = os.path.join(SubPath, f'{mName}.sv')

            if m1Pattern.search(b):
                with open(f1, 'w', encoding='UTF-8') as fp_out:
                    print(f"write module {mName}!\n")
                    fp_out.writelines(t)
                t = []

        if t != []:
            print(f"Omit content:\n{t}")


def SplitIterate(PathName):
    # Use a breakpoint in the code line below to debug your script.
    print(f'Hi, Split {PathName}!\n')  # Press Ctrl+F8 to toggle the breakpoint.

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
                vlogSplit(fpathe, f1)

    with open("./cmdList.sh", 'w') as fw:
        fw.writelines(cmdList)


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    SplitIterate('./')
    # vlogSplit('./', 'oran_radio_if_torwave_regif.sv')
    # vlogClean('./', 'can_v5_0_rfs.vhd')
