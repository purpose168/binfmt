#!/work/shebang3.sh
# 这是一个测试嵌套 shebang（脚本解释器声明）的脚本
#
# Shebang（#!）是 Unix/Linux 系统中用于指定脚本解释器的特殊标记
# 当执行这个脚本时，系统会解析第一行并使用指定的解释器来执行
#
# 本行说明：
# #! - shebang 标记，告诉系统这是一个可执行脚本
# /work/shebang3.sh - 解释器的路径（/work 目录下的 shebang3.sh 脚本）
#
# 执行流程：
# 1. 系统读取第一行的 shebang
# 2. 使用 /work/shebang3.sh 作为解释器
# 3. shebang3.sh 本身也是一个脚本，它的 shebang 是 #!/work/printargs
# 4. 系统会解析 shebang3.sh 的 shebang，使用 /work/printargs 作为解释器
# 5. printargs 程序会接收 shebang4.sh 脚本文件作为参数
# 6. printargs 会打印出它接收到的参数（即 shebang4.sh 脚本文件的路径）
#
# 测试目的：
# 验证 shebang 可以指向另一个脚本（嵌套 shebang）
# 验证 binfmt 功能能够正确处理嵌套的 shebang
# 这是 binfmt 功能的高级测试用例
#
# 注意事项：
# - 这是一个嵌套的 shebang 测试
# - shebang4.sh -> shebang3.sh -> printargs
# - 这种嵌套调用在大多数系统中是支持的
# - 但某些系统可能会限制嵌套的深度
