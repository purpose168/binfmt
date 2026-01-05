# 使用 Node.js 12 的精简版作为基础镜像
# node:12-slim 包含了 Node.js 12 运行时环境
# slim 版本体积更小，适合容器化部署
FROM node:12-slim

# 设置工作目录为 /js
# WORKDIR 指定容器内的工作目录
# 后续命令会在这个目录下执行
WORKDIR /js

# 全局安装 webpack 和 webpack-cli
# npm install -g 表示全局安装
# webpack@4.43.0 指定 webpack 版本为 4.43.0
# webpack-cli@3.3.12 指定 webpack-cli 版本为 3.3.12
# webpack 是一个模块打包工具，用于打包 JavaScript 应用
# webpack-cli 是 webpack 的命令行界面工具
RUN npm install -g webpack@4.43.0 webpack-cli@3.3.12

# 复制 package.json 到工作目录
# package.json 包含项目的依赖信息和配置
# COPY ./package.json /js 将当前目录的 package.json 复制到容器的 /js 目录
COPY ./package.json /js

# 复制 package-lock.json 到工作目录
# package-lock.json 锁定依赖的确切版本，确保可重复构建
# COPY ./package-lock.json /js 将当前目录的 package-lock.json 复制到容器的 /js 目录
COPY ./package-lock.json /js

# 安装项目依赖
# npm install . 根据 package.json 安装所有依赖
# 这会下载并安装 package.json 中列出的所有依赖包
RUN npm install .

# 复制所有源代码到工作目录
# COPY . /js 将当前目录的所有文件和子目录复制到容器的 /js 目录
# 这包括项目的所有源代码文件
COPY . /js

# 定义构建参数 QEMU_STRACE
# ARG 用于定义构建时的参数，可以在构建时传递
# QEMU_STRACE 可能用于调试 QEMU 模拟器
ARG QEMU_STRACE

# 运行 webpack 构建并显示详细信息
# webpack 是打包工具，用于构建和打包 JavaScript 应用
# 各参数说明如下：
RUN webpack\
    # --verbose 显示详细输出信息
    --verbose\
    # --display=verbose 设置显示模式为详细模式
    --display=verbose\
    # --info-verbosity=verbose 设置信息详细程度为详细
    --info-verbosity=verbose\
    # --display-exclude 排除某些信息的显示
    --display-exclude\
    # --display-modules 显示所有模块信息
    --display-modules\
    # --display-max-modules 显示最大模块数
    --display-max-modules\
    # --display-chunks 显示代码块信息
    --display-chunks\
    # --display-entrypoints 显示入口点信息
    --display-entrypoints\
    # --display-origins 显示模块来源信息
    --display-origins\
    # --display-cached 显示缓存信息
    --display-cached\
    # --display-cached-assets 显示缓存的资源信息
    --display-cached-assets\
    # --display-reasons 显示模块包含的原因
    --display-reasons\
    # --display-depth 显示模块深度
    --display-depth\
    # --display-used-exports 显示使用的导出
    --display-used-exports\
    # --display-provided-exports 显示提供的导出
    --display-provided-exports\
    # --display-optimization-bailout 显示优化回退信息
    --display-optimization-bailout\
    # --display-error-details 显示错误详细信息
    --display-error-details 
