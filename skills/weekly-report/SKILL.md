---
name: weekly-report
description: 根据 git 仓库中指定 author 的本周 commit 自动生成技术周报。按 conventional commit 规范自动归类填入周报模板的"本周核心工作"和"日常技术工作"章节,主观章节(项目风险/下周计划/个人成长等)保留模板原文,提示用户补全。Use when user mentions 写周报,本周周报,生成周报,周报模版,weekly report,本周工作总结。
---

# 写周报 (Weekly Report)

根据指定 git 账户的本周 commit 记录,自动填充周报模板中的客观章节,主观章节保留原模板待用户补全。

## Quick Start

用户提供任一触发词后,确认以下信息:

| 参数 | 必填 | 默认值 |
|---|---|---|
| Git 作者 (姓名/邮箱) | 是 | 无 |
| 仓库路径 | 否 | 当前工作目录 |
| 时间范围 (开始/结束) | 否 | 本周一(00:00) 至 今日(23:59) |

最小调用示例:
> 写本周周报,作者 zhangsan@company.com

## Workflow

1. **确认参数**:用 AskUserQuestion 确认 git 作者、时间范围(如未指定则默认本周一至今)、仓库路径(默认当前目录)。
2. **运行提取脚本**:
   ```bash
   bash scripts/extract_commits.sh --author "<author>" [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--path <repo>]
   ```
   脚本输出格式见下文"输出格式"。
3. **解析 commit 列表**:提取 hash、日期、conventional commit 的 type/scope、subject。
4. **按 scope 聚合**:把 commit 按 `scope` 字段分组,作为 1.1"重点项目进度"的行。
5. **按 type 计数**:对 1.2"日常技术工作"做数量统计(见下表)。
6. **填充模板**:见 [references/template.md](references/template.md)。
7. **渲染输出**:把填充后的完整周报以 markdown 输出到对话。

## Commit Type → 周报章节 映射

| Conventional Commit Type | 归入章节 | 字段填充方式 |
|---|---|---|
| `feat` | 1.1 重点项目进度 | 按 scope 分组,每行一个 scope 及其 subject 列表 |
| `fix` | 1.2 线上问题处理 | 按数量计数 |
| `refactor` / `test` | 1.2 代码质量优化 | 按数量计数 |
| `docs` | 1.2 技术文档编写 | 按数量计数 |
| `chore` / `build` / `ci` / `style` / `perf` | 1.2 其他 | 聚合后简短描述 |
| 无 type 前缀(非 conventional) | 1.1 重点项目进度 | 列为"未分类"项目 |

**注意**:
- "代码评审"次数无 commit 数据可推,固定留空。
- "代码覆盖率提升"等量化指标无法从 commit 推,留空。

## 脚本输出格式

`extract_commits.sh` 输出形如:

```
=== META ===
AUTHOR: zhangsan@company.com
SINCE: 2026-06-08
UNTIL: 2026-06-12
REPO: /Users/curveslink/projects/foo
=== COMMITS ===
abc1234|2026-06-12 10:23:11 +0800|feat(user): 新增用户列表分页
def5678|2026-06-11 16:45:02 +0800|fix(order): 修复订单金额计算错误
...
```

Agent 解析逻辑:commit 行格式为 `hash|date|subject`,subject 形如 `type(scope): description` 时按 conventional commit 解析;否则 scope 留空、type 设为 "other"。

## 高级用法

- 自定义类型映射:直接编辑 SKILL.md 中的映射表
- 跨仓库:对每个仓库分别运行脚本,把 commit 合并后填充
- 历史周报:指定 `--since` 和 `--until` 即可
