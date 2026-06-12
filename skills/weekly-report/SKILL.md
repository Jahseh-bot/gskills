---
name: weekly-report
description: 根据 git 仓库中指定 author 的本周 commit 自动生成技术周报。支持单仓库或多仓库工作区(自动遍历子仓库),作者可选(不指定则汇总所有作者)。按 conventional commit 规范结合 scope 主题与文件路径聚类出"重点项目",自动填入周报模板的"本周核心工作"和"日常技术工作"章节,主观章节(项目风险/下周计划/个人成长等)保留模板原文,提示用户补全。Use when user mentions 写周报,本周周报,生成周报,周报模版,weekly report,本周工作总结。
---

# 写周报 (Weekly Report)

根据指定 git 账户的本周 commit 记录,自动填充周报模板中的客观章节,主观章节保留原模板待用户补全。

## Quick Start

用户提供任一触发词后,按以下默认参数表确认。**只有用户主动给出 author 时才使用 `--author`**;否则汇总该目录下所有提交。

| 参数 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| Git 作者 (姓名/邮箱) | 否 | 无(不过滤) | 不指定 → 汇总所有作者 |
| 路径 | 否 | 当前工作目录 | 可是单个 git 仓库,也可是包含多个仓库的工作区目录 |
| 时间范围 (开始/结束) | 否 | 本周一(00:00) 至 今日(23:59) | |
| 多仓库扫描深度 | 否 | 4 | 仅当 path 不是 git 仓库时才生效 |

最小调用示例:
> 写本周周报,作者 zhangsan@company.com
> 写本周周报,扫描整个 workspace 目录(不需要指定作者)

## Workflow

1. **确认参数**:用 AskUserQuestion 确认 author(可选)、时间范围、扫描路径。**关键判断**:用户没明确给作者时,直接不传 `--author`;不要默认填入当前 git config 的用户。
2. **运行提取脚本**:
   ```bash
   bash scripts/extract_commits.sh \
     [--author "<author>"] \
     [--since YYYY-MM-DD] [--until YYYY-MM-DD] \
     [--path <dir>] [--max-depth N]
   ```
   脚本会自动判断 path 是单仓库还是多仓库工作区;META 块的 `MODE` 字段告诉你结果。
3. **解析 META**:读取 `MODE`、`REPOS_FOUND`、`REPO:` 列表,记住"本次周报覆盖了哪些仓库"。
4. **解析每个 commit 记录**:提取 `REPO`、hash、date、subject(含 conventional commit 的 type/scope)、body、files。
5. **聚类成"重点项目"**:见下文"项目聚类与命名"——以业务主题为单位,可跨 scope 也可跨仓库。
6. **填充 1.2 日常技术工作**:对剩余 commit 按 type 计数(见映射表)。
7. **填充模板**:见 [references/template.md](references/template.md)。
8. **渲染输出**:把填充后的完整周报以 markdown 输出到对话。

## 项目聚类与命名

> 这是本 skill 区别于"按 scope 机械分组"的核心规则。脚本提供了 REPO + subject + body + files,Agent 必须用所有这些信号做语义聚类。

### 聚类步骤

对所有 `feat` 及无 type 前缀的 commit:

1. **抽取信号**:对每个 commit 收集 `REPO`、`scope`、subject 关键词、body 关键词、所有变更文件的顶层目录(如 `src/user/list.ts` → 顶层 `user`)。
2. **按主题归组**(优先级从高到低):
   - **共同业务主题**:多个仓库 + 多个 scope 但 subject/body 反复出现同一业务名词(如"订单"、"对账"、"风控") → 同一项目。**跨仓库聚类是常见情况**,例如 `Toonflow-app` 和 `Toonflow-web` 的提交大概率属于同一"Toonflow 项目"。
   - **共同 scope 前缀**:`user-list` / `user-detail` / `user-auth` → 同一"用户模块"项目。
   - **共同文件路径根**:多个 commit 都修改 `src/payment/...` → 归入"支付模块",即便 scope 不同。
   - **同一仓库兜底**:无法语义归类时,以仓库名作为项目名(如"AiToEarn 仓库维护")。
   - **未匹配** commit 单独归入"其他/未分类项目"。
3. **命名项目**:用中文领域名(如"用户中心"、"订单核心流程"、"支付对账"),避免直接用 scope 字符串。一个项目可由多个 scope 及多个仓库组成。
4. **排序**:按 commit 数量 → 涉及仓库数 → 总变更文件数 → 是否含里程碑式 subject(发布/上线/release)降序。最重要的放第一行。

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
- 计数维度建议同时给出"总计 N(跨 M 个仓库)"——多仓库模式下能直观反映工作分布。
- "代码评审"次数无 commit 数据可推,固定留空。
- "代码覆盖率提升"等量化指标无法从 commit 推,留空。
- 若某个 fix/refactor commit 显然属于某个 1.1 项目(同一 scope 或同一文件路径根),也可作为补充信息在该项目"实际完成情况"中提及,但不重复计入 1.2。

## 脚本输出格式

`extract_commits.sh` 输出形如:

```
=== META ===
AUTHOR: zhangsan@company.com           # 或 "(all authors)" 表示未过滤
SINCE: 2026-06-08
UNTIL: 2026-06-12
SCAN_ROOT: /Users/me/workspace
MODE: single-repo                       # 或 multi-repo
REPOS_FOUND: 3
REPO: foo|/Users/me/workspace/foo
REPO: bar|/Users/me/workspace/bar
REPO: baz|/Users/me/workspace/baz
=== COMMITS ===
===WEEKLY_COMMIT===
REPO: foo
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
- META 中 `REPO: <name>|<abs_path>` 用 `|` 分隔仓库名与绝对路径。
- 每个 commit 以 `===WEEKLY_COMMIT===` 起始,首字段 `REPO:` 表示该 commit 所在仓库名(与 META 列表对应)。
- 其余字段为定行前缀 `HASH:` / `DATE:` / `SUBJECT:`。
- `subject` 形如 `type(scope): description` 时按 conventional commit 解析;否则 type=`other`、scope=空。
- body 是 `---BODY---` 与 `---END_BODY---` 之间的所有行(可能多行、可能为空)。
- files 是 `---FILES---` 与 `---END_FILES---` 之间的所有行,每行格式 `<status>\t<path>`(status: A/M/D/R100 等)。
- 多仓库模式下,被扫描但 0 commit 的仓库不会出现在 COMMITS 中,但仍列在 META 的 REPO 列表里——可在周报开头说明"扫描了 N 个仓库,M 个有提交"。

## 高级用法

- **自定义类型映射**:直接编辑本 SKILL.md 中的映射表。
- **指定扫描深度**:`--max-depth` 控制多仓库发现的最大深度(默认 4)。脚本会自动跳过 `node_modules` / `vendor` / `dist` / `build` / `target` / `.next` / `.venv` / `Pods` / `__pycache__` / `.gradle` 等重目录。
- **强制单仓库**:把 `--path` 指到某个仓库根即可,脚本检测到 `.git` 就只扫该仓库,不会向上回溯。
- **历史周报**:指定 `--since` 和 `--until` 即可。
- **微调聚类**:若 agent 聚类结果不符合预期,可在调用时追加自然语言提示,如"把 `auth-*` 和 `user-*` 归入同一'用户中心'项目"或"`Toonflow-app` 和 `Toonflow-web` 合并为同一项目"。
