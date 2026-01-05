#!/work/printargs
# 这是一个测试 shebang（脚本解释器声明）绝对路径的脚本
#
# Shebang（#!）是 Unix/Linux 系统中用于指定脚本解释器的特殊标记
# 当执行这个脚本时，系统会解析第一行并使用指定的解释器来执行
#
# 本行说明：
# #! - shebang 标记，告诉系统这是一个可执行脚本
# /work/printargs - 解释器的路径（/work 目录下的 printargs 程序）
#
# 执行流程：
# 1. 系统读取第一行的 shebang
# 2. 使用 /work/printargs 作为解释器
# 3. printargs 程序会接收这个脚本文件作为参数
# 4. printargs 会打印出它接收到的参数（即这个脚本文件的路径）
#
# 测试目的：
# 验证 shebang 可以使用绝对路径作为解释器
# 验证 binfmt 功能能够正确处理绝对路径的 shebang
# 这是 binfmt 功能的基础测试用例
#
# 与 shebang.sh 的区别：
# - shebang.sh 使用相对路径 ./printargs
# - shebang3.sh 使用绝对路径 /work/printargs
# 两者功能相同，但路径表示方式不同
