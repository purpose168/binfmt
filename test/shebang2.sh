#!./printargs arg
# 这是一个测试 shebang（脚本解释器声明）带参数的脚本
#
# Shebang（#!）是 Unix/Linux 系统中用于指定脚本解释器的特殊标记
# 当执行这个脚本时，系统会解析第一行并使用指定的解释器来执行
#
# 本行说明：
# #! - shebang 标记，告诉系统这是一个可执行脚本
# ./printargs - 解释器的路径（当前目录下的 printargs 程序）
# arg - 传递给解释器的参数
#
# 执行流程：
# 1. 系统读取第一行的 shebang
# 2. 使用 ./printargs 作为解释器
# 3. 将 arg 作为参数传递给 printargs
# 4. printargs 程序会接收两个参数：
#    - 第一个参数：这个脚本文件的路径
#    - 第二个参数：arg
# 5. printargs 会打印出它接收到的所有参数
#
# 测试目的：
# 验证 shebang 可以包含参数
# 验证 binfmt 功能能够正确处理带参数的 shebang
# 这是 binfmt 功能的重要测试用例
