---
name: weekly-report
description: 根据 git 仓库中指定 author 的本周 commit 自动生成技术周报。按 conventional commit 规范结合 scope 主题与文件路径聚类出"重点项目",自动填入周报模板的"本周核心工作"和"日常技术工作"章节,主观章节(项目风险/下周计划/个人成长等)保留模板原文,提示用户补全。Use when user mentions 写周报,本周周报,生成周报,周报模版,weekly report,本周工作总结。
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
   脚本输出格式见下文"脚本输出格式"。
3. **解析每个 commit 记录**:提取 hash、date、subject(含 conventional commit 的 type/scope)、body、files。
4. **聚类成"重点项目"**:见下文"项目聚类与命名"——不是每个 scope = 一个项目,而是按主题与文件路径根聚合。
5. **填充 1.2 日常技术工作**:对剩余 commit 按 type 计数(见映射表)。
6. **填充模板**:见 [references/template.md](references/template.md)。
7. **渲染输出**:把填充后的完整周报以 markdown 输出到对话。

## 项目聚类与命名

> 这是本 skill 区别于"按 scope 机械分组"的核心规则。脚本提供了 subject + body + files,Agent 必须用所有这些信号做语义聚类。

### 聚类步骤

对所有 `feat` 及无 type 前缀的 commit:

1. **抽取信号**:对每个 commit 收集 `scope`、subject 关键词、body 关键词、所有变更文件的顶层目录(如 `src/user/list.ts` → 顶层 `user`)。
2. **按主题归组**(优先级从高到低):
   - **共同 scope 前缀**:`user-list` / `user-detail` / `user-auth` → 同一"用户模块"项目。
   - **共同文件路径根**:多个 commit 都修改 `src/payment/...` → 归入"支付模块",即便 scope 不同。
   - **共同业务关键词**:subject/body 中反复出现的业务名词(如"订单"、"对账"、"风控")。
   - **未匹配** commit 单独归入"其他/未分类项目"。
3. **命名项目**:用中文领域名(如"用户中心"、"订单核心流程"、"支付对账"),避免直接用 scope 字符串。一个项目可由多个 scope 组成。
4. **排序**:按 commit 数量 → 总变更文件数 → 是否含里程碑式 subject(发布/上线/release)降序。最重要的放第一行。

### 项目阶段推断

从该项目所有 commit 的 subject + body 关键词推断 `项目阶段` 字段:

| 关键词 | 阶段 |
|---|---|
| 上线、发布、release、launch、rollout | 上线 |
| 测试、验证、联调、e2e、QA、UAT | 测试 |
| 其他(默认) | 开发 |

如同时出现多种,取时间最近的 commit 为准。

### 关键成果/产出物推断

从该项目 commit 的 subject + body 抽取动词短语(如"新增 XX 接口"、"完成 XX 迁移"、"上线 XX 功能"),拼成"关键成果"候选,并附"请用户确认/补全量化指标"提示。

## Commit Type → 周报章节 映射

| Conventional Commit Type | 归入章节 | 字段填充方式 |
|---|---|---|
| `feat` | 1.1 重点项目进度 | 经项目聚类后,每行一个项目 |
| 无 type 前缀(非 conventional) | 1.1 重点项目进度 | 与 feat 一起进入聚类;若无法归入任何项目则进入"其他/未分类" |
| `fix` | 1.2 线上问题处理 | 按数量计数 |
| `refactor` / `test` | 1.2 代码质量优化 | 按数量计数 |
| `docs` | 1.2 技术文档编写 | 按数量计数 |
| `chore` / `build` / `ci` / `style` / `perf` | 1.2 其他 | 聚合后简短描述 |

**注意**:
- "代码评审"次数无 commit 数据可推,固定留空。
- "代码覆盖率提升"等量化指标无法从 commit 推,留空。
- 若某个 fix/refactor commit 显然属于某个 1.1 项目(同一 scope 或同一文件路径根),也可作为补充信息在该项目"实际完成情况"中提及,但不重复计入 1.2。

## 脚本输出格式

`extract_commits.sh` 输出形如:

```
=== META ===
AUTHOR: zhangsan@company.com
SINCE: 2026-06-08
UNTIL: 2026-06-12
REPO: foo
REPO_PATH: /Users/me/projects/foo
=== COMMITS ===
===WEEKLY_COMMIT===
HASH: abc1234...
DATE: 2026-06-12 10:23:11 +0800
SUBJECT: feat(user-list): 新增用户列表分页
---BODY---
详细说明 page/size 参数处理
关联需求 PRD-123
---END_BODY---
---FILES---
M	src/user/list.ts
A	src/user/list.test.ts
---END_FILES---
===WEEKLY_COMMIT===
...
```

Agent 解析规则:
- 每个 commit 以 `===WEEKLY_COMMIT===` 起始,字段为定行前缀 `HASH:` / `DATE:` / `SUBJECT:`。
- `subject` 形如 `type(scope): description` 时按 conventional commit 解析;否则 type=`other`、scope=空。
- body 是 `---BODY---` 与 `---END_BODY---` 之间的所有行(可能多行、可能为空)。
- files 是 `---FILES---` 与 `---END_FILES---` 之间的所有行,每行格式 `<status>\t<path>`(status: A/M/D/R100 等)。

## 高级用法

- **自定义类型映射**:直接编辑本 SKILL.md 中的映射表。
- **跨仓库**:对每个仓库分别运行脚本,把 META 中的 `REPO` 作为聚类的额外维度(同名项目可跨仓库合并)。
- **历史周报**:指定 `--since` 和 `--until` 即可。
- **微调聚类**:若 agent 聚类结果不符合预期,可在调用时追加自然语言提示,如"把 `auth-*` 和 `user-*` 归入同一'用户中心'项目"。
