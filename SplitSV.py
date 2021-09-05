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
                f1 = os.path.join(SubPath, f'{mName}.v')

            if m1Pattern.search(b):
                with open(f1, 'w', encoding='UTF-8') as fp_out:
                    fp_out.writelines(t)
                t = []

        if t != []:
            print(f"Omit content:\n{t}")


# Press the green button in the gutter to run the script.
if __name__ == '__main__':
    vlogSplit('./', 'oran_radio_if_torwave_regif.sv')
# vlogClean('./', 'can_v5_0_rfs.vhd')
