#!/usr/bin/env bats
# 使用 Bats（Bash Automated Testing System）测试框架
# Bats 是一个用于测试 shell 脚本的自动化测试框架
# /usr/bin/env bats 会查找 PATH 中的 bats 解释器

# 加载断言库
# load 是 Bats 提供的命令，用于加载外部库文件
# "assert" 是断言库的名称，提供了各种断言函数
# 这些断言函数包括：assert_success、assert_output、assert_equal 等
load "assert"

# 定义 exec0 辅助函数
# 这个函数用于执行 execargv0 程序，并处理模拟器相关的逻辑
# $@ 表示传递给函数的所有参数
exec0() {
  # 检查是否设置了 BINFMT_EMULATOR 环境变量
  # -z 测试字符串是否为空
  # $BINFMT_EMULATOR 是环境变量，指定要使用的模拟器（如 aarch64、x86_64）
  # 如果为空，表示不需要使用模拟器
  if [ -z "$BINFMT_EMULATOR" ]; then
    # 直接运行 execargv0 程序
    # run 是 Bats 提供的命令，用于执行命令并捕获输出和退出码
    # ./execargv0 是要执行的程序
    # "$@" 是传递给 execargv0 的所有参数
    run ./execargv0 "$@"
  else 
    # 如果设置了模拟器，则使用模拟器运行程序
    # PATH=/crossarch/usr/bin:/crossarch/bin:$PATH 设置 PATH 环境变量
    #   - /crossarch/usr/bin 是交叉架构的 /usr/bin 目录
    #   - /crossarch/bin 是交叉架构的 /bin 目录
    #   - $PATH 是原有的 PATH
    # buildkit-qemu-$BINFMT_EMULATOR 是 QEMU 模拟器的名称
    #   - buildkit-qemu- 是前缀
    #   - $BINFMT_EMULATOR 是模拟器架构（如 aarch64、x86_64）
    # ./execargv0 是要执行的程序
    # "$@" 是传递给 execargv0 的所有参数
    PATH=/crossarch/usr/bin:/crossarch/bin:$PATH run buildkit-qemu-$BINFMT_EMULATOR ./execargv0 "$@"
  fi
}

# 定义 execdirect 辅助函数
# 这个函数用于直接执行命令，不通过 execargv0
# $@ 表示传递给函数的所有参数
execdirect() {
  # 检查是否设置了 BINFMT_EMULATOR 环境变量
  if [ -z "$BINFMT_EMULATOR" ]; then
    # 直接运行命令
    # run 是 Bats 提供的命令，用于执行命令并捕获输出和退出码
    # "$@" 是要执行的命令和参数
    run "$@"
  else 
    # 如果设置了模拟器，则使用模拟器运行命令
    # PATH=/crossarch/usr/bin:/crossarch/bin:$PATH 设置 PATH 环境变量
    # buildkit-qemu-$BINFMT_EMULATOR 是 QEMU 模拟器的名称
    # "$@" 是要执行的命令和参数
    PATH=/crossarch/usr/bin:/crossarch/bin:$PATH run buildkit-qemu-$BINFMT_EMULATOR "$@"
  fi
}

# 测试用例：单次执行
# @test 是 Bats 的测试用例声明语法
# "exec-single" 是测试用例的名称
@test "exec-single" {
  # 执行 execargv0 程序，传递 printargs 和参数
  # exec0 是上面定义的辅助函数
  # ./printargs 是要执行的程序
  # foo bar1 bar2 是传递给 printargs 的参数
  exec0 ./printargs foo bar1 bar2
  # 断言命令执行成功（退出码为 0）
  assert_success
  # 断言输出为 "foo bar1 bar2"
  # printargs 程序会打印出它接收到的参数
  assert_output "foo bar1 bar2"
}

# 测试用例：多次执行
@test "exec-multi" {
  # 执行 execargv0 程序，传递 printargs 程序作为参数
  # ./execargv0 是第一个程序
  # ./printargs 是传递给 execargv0 的第一个参数（要执行的程序）
  # ./printargs 是传递给 execargv0 的第二个参数（要执行的程序）
  # baz 是传递给 printargs 的参数
  exec0 ./execargv0 ./printargs ./printargs baz
  # 断言命令执行成功
  assert_success
  # 断言输出为 "baz"
  # execargv0 会执行第一个 printargs，第一个 printargs 会执行第二个 printargs
  # 第二个 printargs 会打印 baz
  assert_output "baz"
}

# 测试用例：多次执行（绝对路径）
@test "exec-multi-abs" {
  # 执行 execargv0 程序，使用绝对路径
  # $(pwd) 获取当前工作目录的绝对路径
  # $(pwd)/printargs 是 printargs 的绝对路径
  exec0 ./execargv0 $(pwd)/printargs $(pwd)/printargs baz
  # 断言命令执行成功
  assert_success
  # 断言输出为 "baz"
  assert_output "baz"
}

# 测试用例：基于 PATH 的执行
@test "exec-multi-path" {
  # 将 printargs 复制到 /usr/bin 目录，并重命名为 test-printargs
  # cp 是复制命令
  # $(pwd)/printargs 是源文件路径
  # /usr/bin/test-printargs 是目标文件路径
  cp $(pwd)/printargs /usr/bin/test-printargs
  # 执行 execargv0 程序，使用 PATH 中的程序
  # test-printargs 是通过 PATH 查找的程序
  exec0 test-printargs test-printargs abc
  # 断言命令执行成功
  assert_success
  # 断言输出为 "test-printargs abc"
  # 第一个 test-printargs 是程序名称，第二个是参数
  assert_output "test-printargs abc"
}

# 测试用例：直接执行
@test "exec-direct" {
  # 直接执行 test-printargs 程序
  # execdirect 是上面定义的辅助函数
  # test-printargs 是要执行的程序
  # foo bar1 是传递给程序的参数
  execdirect test-printargs foo bar1
  # 断言命令执行成功
  assert_success
  # 断言输出为 "test-printargs foo bar1"
  # printargs 会打印程序名称和所有参数
  assert_output "test-printargs foo bar1"
}

# 测试用例：直接执行（绝对路径）
@test "exec-direct-abs" {
  # 直接执行 printargs 程序，使用绝对路径
  # $(pwd)/printargs 是 printargs 的绝对路径
  execdirect $(pwd)/printargs foo bar1
  # 断言命令执行成功
  assert_success
  # 断言输出为绝对路径和参数
  # $(pwd) 会被替换为当前工作目录的实际路径
  assert_output "$(pwd)/printargs foo bar1"
}

# 测试用例：shebang 测试
@test "shebang" {
  # 执行 shebang.sh 脚本
  # ./shebang.sh 的 shebang 是 #!./printargs
  # arg1 arg2 是传递给脚本的参数
  exec0 ./shebang.sh arg1 arg2
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs $(pwd)/shebang.sh arg2"
  # ./printargs 是 shebang 中指定的解释器
  # $(pwd)/shebang.sh 是脚本文件的绝对路径
  # arg2 是传递给脚本的第二个参数（arg1 被 shebang 消耗了）
  assert_output "./printargs $(pwd)/shebang.sh arg2"
}

# 测试用例：带参数的 shebang 测试
@test "shebang-arg" {
  # 执行 shebang2.sh 脚本
  # ./shebang2.sh 的 shebang 是 #!./printargs arg
  # arg1 arg2 是传递给脚本的参数
  exec0 ./shebang2.sh arg1 arg2
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs arg $(pwd)/shebang2.sh arg2"
  # ./printargs 是 shebang 中指定的解释器
  # arg 是 shebang 中的参数
  # $(pwd)/shebang2.sh 是脚本文件的绝对路径
  # arg2 是传递给脚本的第二个参数（arg1 被 shebang 消耗了）
  assert_output "./printargs arg $(pwd)/shebang2.sh arg2"
}

# 测试用例：绝对路径 shebang 测试
@test "shebang-abs" {
  # 执行 shebang3.sh 脚本
  # ./shebang3.sh 的 shebang 是 #!/work/printargs
  # arg1 arg2 是传递给脚本的参数
  exec0 ./shebang3.sh arg1 arg2
  # 断言命令执行成功
  assert_success
  # 断言输出为 "/work/printargs $(pwd)/shebang3.sh arg2"
  # /work/printargs 是 shebang 中指定的解释器（绝对路径）
  # $(pwd)/shebang3.sh 是脚本文件的绝对路径
  # arg2 是传递给脚本的第二个参数（arg1 被 shebang 消耗了）
  assert_output "/work/printargs $(pwd)/shebang3.sh arg2"
}

# 测试用例：嵌套 shebang 测试
@test "shebang-multi" {
  # 执行 shebang4.sh 脚本
  # ./shebang4.sh 的 shebang 是 #!/work/shebang3.sh
  # /work/shebang3.sh 的 shebang 是 #!/work/printargs
  # arg1 arg2 是传递给脚本的参数
  exec0 ./shebang4.sh arg1 arg2
  # 断言命令执行成功
  # 断言输出为 "/work/printargs $(pwd)/shebang3.sh $(pwd)/shebang4.sh arg2"
  # /work/printargs 是最终的解释器
  # $(pwd)/shebang3.sh 是第一个脚本的绝对路径
  # $(pwd)/shebang4.sh 是第二个脚本的绝对路径
  # arg2 是传递给脚本的第二个参数（arg1 被第一个 shebang 消耗了）
  assert_output "/work/printargs $(pwd)/shebang3.sh $(pwd)/shebang4.sh arg2"
}

# 测试用例：直接执行 shebang 脚本
@test "shebang-direct" {
  # 直接执行 shebang.sh 脚本
  # 不使用 execargv0，直接通过 execdirect 执行
  execdirect ./shebang.sh foo bar1
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs ./shebang.sh foo bar1"
  # 注意：这里不会将路径转换为绝对路径，因为使用的是相对路径
  assert_output "./printargs ./shebang.sh foo bar1"
}

# 测试用例：相对路径执行
@test "relative-exec" {
  # 执行 env 命令，传递 env 和 printargs 作为参数
  # 第一个 env 是要执行的程序
  # 第二个 env 是传递给第一个 env 的参数
  # ./printargs 是传递给第二个 env 的参数
  # foo bar1 bar2 是传递给 printargs 的参数
  exec0 env env ./printargs foo bar1 bar2
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs foo bar1 bar2"
  assert_output "./printargs foo bar1 bar2"
}

# 测试用例：基于 PATH 的执行
@test "path-based-exec" {
  # 设置 PATH 环境变量，添加 /work 目录
  # PATH="$PATH:/work" 将 /work 添加到 PATH 的末尾
  # 这样就可以在 /work 目录中查找程序
  PATH="$PATH:/work" exec0 env env printargs foo bar1 bar2
  # 断言命令执行成功
  assert_success
  # 断言输出为 "printargs foo bar1 bar2"
  # 注意：这里使用的是程序名称，而不是路径
  assert_output "printargs foo bar1 bar2"
}

# 测试用例：带路径的 shebang 测试
@test "shebang-path" {
  # 执行 shebang-path.sh 脚本
  # ./shebang-path.sh 的 shebang 是 #!/work/env ./printargs
  # ./shebang-path.sh foo bar1 是传递给脚本的参数
  exec0 ./shebang-path.sh ./shebang-path.sh foo bar1
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs /work/shebang-path.sh foo bar1"
  # /work/env 是 shebang 中指定的解释器
  # ./printargs 是传递给 env 的参数
  # /work/shebang-path.sh 是脚本文件的路径
  # foo bar1 是传递给脚本的参数
  assert_output "./printargs /work/shebang-path.sh foo bar1"
}

# 测试用例：带路径的 shebang shell 测试
@test "shebang-path-shell" {
  # 执行 shebang-path2.sh 脚本
  # ./shebang-path2.sh 的 shebang 是 #!/work/env sh
  # ./shebang-path2.sh foo bar1 是传递给脚本的参数
  exec0 ./shebang-path2.sh ./shebang-path2.sh foo bar1
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs foo bar1"
  # shebang-path2.sh 会执行 printargs 程序
  # foo bar1 是传递给 printargs 的参数
  assert_output "./printargs foo bar1"
}

# 测试用例：shell 命令相对路径测试
@test "shell-command-relative" {
  # 检查是否设置了 BINFMT_EMULATOR 环境变量
  # -n 测试字符串是否非空
  if [ -n "$BINFMT_EMULATOR" ]; then
    # 如果设置了模拟器，跳过此测试
    # skip 是 Bats 提供的命令，用于跳过测试
    # "prepend_workdir_if_relative is altering the behaviour for args when run under emulation" 是跳过原因
    # 说明：在模拟器下，prepend_workdir_if_relative 会改变参数的行为
    skip "prepend_workdir_if_relative is altering the behaviour for args when run under emulation"
  fi

  # 执行 sh 命令，传递 sh 和 -c 参数
  # 第一个 sh 是要执行的程序
  # 第二个 sh 是传递给第一个 sh 的参数
  # -c 是 sh 的选项，表示从字符串读取命令
  # './shebang-path.sh foo bar1 bar2' 是要执行的命令
  exec0 sh sh -c './shebang-path.sh foo bar1 bar2'
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs ./shebang-path.sh foo bar1 bar2"
  assert_output "./printargs ./shebang-path.sh foo bar1 bar2"
}

# 测试用例：shell 命令相对路径直接执行测试
@test "shell-command-relative-direct" {
  # 检查是否设置了 BINFMT_EMULATOR 环境变量
  if [ -n "$BINFMT_EMULATOR" ]; then
    # 如果设置了模拟器，跳过此测试
    skip "prepend_workdir_if_relative is altering the behaviour for args when run under emulation"
  fi

  # 直接执行 sh 命令
  # sh 是要执行的程序
  # -c 是 sh 的选项，表示从字符串读取命令
  # './shebang-path.sh foo bar1 bar2' 是要执行的命令
  execdirect sh -c './shebang-path.sh foo bar1 bar2'
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs ./shebang-path.sh foo bar1 bar2"
  assert_output "./printargs ./shebang-path.sh foo bar1 bar2"
}

# 测试用例：shell 命令相对路径嵌套测试
@test "shell-command-relative-nested" {
  # 执行 sh 命令，传递 sh 和 -c 参数
  # 注意：这个测试没有跳过模拟器的情况
  exec0 sh sh -c './shebang-path2.sh foo bar1 bar2'
  # 断言命令执行成功
  assert_success
  # 断言输出为 "./printargs foo bar1 bar2"
  # shebang-path2.sh 会执行 printargs 程序
  # foo bar1 bar2 是传递给 printargs 的参数
  assert_output "./printargs foo bar1 bar2"
}

# 测试用例：改变工作目录并读取自身可执行文件路径
@test "change-workdir-and-read-self-exe" {
  # 执行 chwd 程序
  # ./chwd 是要执行的程序
  # /work/chwd 是传递给 chwd 的参数（期望的工作目录）
  execdirect ./chwd /work/chwd
  # 断言命令执行成功
  assert_success
  # 断言输出为 "/work/chwd"
  # chwd 程序会改变工作目录并读取自身可执行文件的路径
  # 期望输出为 /work/chwd
  assert_output "/work/chwd"
}
