#!/work/env sh
# 这是一个测试 shebang（脚本解释器声明）路径的脚本
#
# Shebang（#!）是 Unix/Linux 系统中用于指定脚本解释器的特殊标记
# 当执行这个脚本时，系统会解析第一行并使用指定的解释器来执行
#
# 本行说明：
# #! - shebang 标记，告诉系统这是一个可执行脚本
# /work/env - 解释器的路径
# sh - 传递给解释器的参数（shell 名称）
#
# 执行流程：
# 1. 系统读取第一行的 shebang
# 2. 使用 /work/env 作为解释器
# 3. 将 sh 作为参数传递给 /work/env
# 4. /work/env 是一个符号链接（在 run.sh 中创建），指向 /usr/bin/env
# 5. 实际执行的是：/usr/bin/env sh
# 6. env 命令会查找并执行 PATH 中的 sh 解释器
# 7. sh 解释器会执行这个脚本的剩余内容
#
# 测试目的：
# 验证 shebang 行中可以包含空格，并且系统能够正确解析
# 这是 binfmt 功能的一个重要测试用例

# 执行 printargs 程序，并传递所有参数
# ./printargs - 执行当前目录下的 printargs 程序
# "$@" - 特殊变量，表示传递给当前脚本的所有参数
#   - $@ 表示所有位置参数（$1, $2, $3, ...）
#   - 双引号确保每个参数保持独立，不会被重新分词
#   - 例如：如果脚本被调用为 ./shebang-path2.sh arg1 arg2
#     那么 "$@" 会被展开为 "arg1" "arg2"
# printargs 程序会打印出它接收到的所有参数
./printargs "$@"
