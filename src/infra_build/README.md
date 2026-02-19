# infra_build 目录说明

该目录承载原 `src/build` 中的源码级构建基础设施，按职责拆分如下：

- `infra_build/cmake`：构建图定义与阶段编排（CMake 模块）
- `infra_build/config`：目标/芯片构建配置与模板
- `infra_build/script`：构建期脚本与工具逻辑
- `infra_build/toolchains`：工具链定义

## 兼容策略（当前）

为避免一次性迁移导致构建中断，`src/build/{cmake,config,script,toolchains}` 当前保留为到本目录的符号链接。

## 目标状态（下一阶段）

1. 将代码中的硬编码路径 `${ROOT_DIR}/build/...` 逐步替换为 `${ROOT_DIR}/infra_build/...`。
2. 清理链接兼容层，最终保留 `src/build` 仅用于构建输出或临时产物。
3. 为脚本接口统一 `in -> command -> out` 清单契约并固定 schema。
