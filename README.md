# 方舟平台快速入门（零依赖版）

欢迎使用方舟平台！本教程专为**零基础用户**设计，无需安装任何编程环境（如 Python），直接使用操作系统内置工具即可体验方舟大模型服务。

## 1. 准备工作

在开始之前，请确保您已经完成以下准备：

1.  **注册账号**：确保您拥有火山引擎账号并已登录。
2.  **获取 API Key**：
    *   访问 [API Key 管理页面](https://console.volcengine.com/ark/region:ark+cn-beijing/apikey)。
    *   点击“创建 API Key”，并复制保存您的 Key。
    *   当前脚本兼容历史 UUID 格式以及新格式 `ark-<uuid>-<suffix>` 的 Key。
    *   *注意：请妥善保管您的 API Key，不要泄露给他人。*
3.  **开通模型**：
    *   确保您已开通 `doubao-seed-2-0-lite` 或类似的豆包模型。
    *   如果没有，请访问 [模型广场](https://console.volcengine.com/ark/region:ark+cn-beijing/model) 申请开通。
    *   **注意**：调用时请使用具体的 Model ID（例如 `doubao-seed-2-0-lite-260215`），**不要**使用 Endpoint ID（以 `ep-` 开头的 ID）。

---

## 2. 阶段一：一键体验（零门槛）

我们为您准备了无需安装任何软件的自动化脚本。脚本启动后会引导您：

1. 输入或确认 `ARK_API_KEY`
2. 选择要体验的能力
3. 查看默认 Prompt，并按需改成自己的 Prompt
4. 获取对应结果

当前已支持以下 5 类能力：

*   **文本生成**：直接返回文本回答。
*   **图片生成**：返回图片结果 URL。
*   **视频生成**：创建任务并轮询状态，成功后返回视频 URL。
*   **多模态向量化**：输入文本 + 图片 URL，返回向量摘要信息。
*   **工具调用（联网工具）**：调用内置联网搜索工具，返回带实时信息的回答。

请根据您的操作系统选择对应的操作。

### Windows 用户

**适用系统**：Windows 7 SP1 及以上（推荐 Windows 10/11）

1.  找到项目文件夹中的 `scripts/zero_dependency/windows` 目录。
2.  双击运行 **`run_windows.bat`** 文件。
    *   *提示：如果这是您第一次运行，可能会弹出权限询问窗口，请输入 `Y` 或允许运行。*
3.  脚本会自动启动 PowerShell 环境。
4.  根据提示输入您的 **API Key** 并回车，或直接使用已配置好的 `ARK_API_KEY`。
    *   *说明：脚本会对 API Key 做本地弱校验。如果格式未被本地规则识别，脚本仍会继续尝试调用，最终以服务端鉴权结果为准。*
5.  在能力菜单中输入编号，选择要体验的能力。
6.  查看脚本展示的 **默认 Prompt**，直接回车可使用默认值，也可以输入自己的 Prompt 覆盖默认值。
7.  如果您选择的是**多模态向量化**，脚本还会继续提示输入图片 URL；直接回车可使用默认图片 URL。
8.  稍等片刻，您将看到对应能力的结果。
9.  成功后，脚本会继续提供后续菜单，您可以：
    * 体验其他能力
    * 创建开发者环境
    * 查看开发者环境会做什么
    * 结束

### macOS 用户

**适用系统**：所有 macOS 版本

1.  找到项目文件夹中的 `scripts/zero_dependency/mac` 目录。
2.  双击运行 **`run_mac.command`** 文件。
    *   *提示：如果系统提示“无法打开，因为它来自未验证的开发者”，请按住 `Control` 键点击文件，选择“打开”，然后在弹出的对话框中再次点击“打开”。*
3.  终端窗口会自动打开。
4.  根据提示输入您的 **API Key** 并回车，或直接使用已配置好的 `ARK_API_KEY`。
    *   *说明：脚本会对 API Key 做本地弱校验。如果格式未被本地规则识别，脚本仍会继续尝试调用，最终以服务端鉴权结果为准。*
5.  在能力菜单中输入编号，选择要体验的能力。
6.  查看脚本展示的 **默认 Prompt**，直接回车可使用默认值，也可以输入自己的 Prompt 覆盖默认值。
7.  如果您选择的是**多模态向量化**，脚本还会继续提示输入图片 URL；直接回车可使用默认图片 URL。
8.  等待片刻，您将看到对应能力的结果。
9.  成功后，脚本会继续提供后续菜单，您可以：
    * 体验其他能力
    * 创建开发者环境
    * 查看开发者环境会做什么
    * 结束

### 能力结果说明

*   **文本生成**：终端直接打印模型回答。
*   **图片生成**：终端打印图片 URL，复制到浏览器即可查看。
    默认使用 `2K` 输出尺寸，以满足当前默认生图模型的最小像素要求。
*   **视频生成**：终端先打印任务 ID，再持续输出 `queued/running/succeeded/failed` 等状态；成功后打印视频 URL。
*   **多模态向量化**：终端打印“向量生成成功”、向量维度和前几个值的摘要，不会输出完整大向量。
*   **工具调用（联网工具）**：终端会先提示已启用联网工具，再输出最终回答。

### 前置条件说明

不同能力依赖不同模型与权限：

*   **文本生成**：需要可用的文本模型权限。
*   **图片生成**：需要已开通图片生成模型。
*   **视频生成**：需要已开通视频生成模型。
*   **多模态向量化**：需要已开通图文向量化模型。
*   **工具调用（联网工具）**：需要所选文本模型支持工具调用与联网搜索。

如果未开通对应能力，脚本会返回错误信息，您可根据提示前往控制台开通模型后重试。

---

## 3. 阶段二：进阶（一键搭建专业开发环境）

如果您已经成功体验了 API 调用，并希望开始真正的 Python 编程开发，但又不想被复杂的环境配置（Python 版本、pip、虚拟环境）所困扰，请尝试我们的**自动化环境构建工具**。

我们将使用现代化的 Python 包管理器 `uv`，为您在项目内部自动下载并配置一个**隔离的、纯净的、标准的** Python 开发环境。

### Windows 用户

1.  进入 `scripts/init_dev_env` 目录。
2.  双击运行 **`setup_windows.bat`**。
3.  脚本会自动执行以下操作：
    *   下载 `uv` 工具。
    *   自动下载 Python 3.12（如果不干扰您的系统 Python）。
    *   创建虚拟环境 `.venv`。
    *   安装方舟 SDK。
4.  完成后，在项目根目录会生成一个 **`run_demo.bat`**。
5.  双击 `run_demo.bat`，即可运行标准的 Python SDK 示例代码 (`python/demo_standard.py`)。
6.  如果您希望按需生成 Python 示例脚本，可运行：
    ```bat
    .\.venv\Scripts\python.exe python\gen_example.py
    ```
    生成器支持多选示例类型、修改默认 Model ID，并可在缺少 `ARK_API_KEY` 时提示输入并选择写入项目根目录 `.env`。

### macOS 用户

1.  打开终端，进入 `scripts/init_dev_env` 目录。
2.  运行构建脚本：
    ```bash
    ./setup_mac.sh
    ```
3.  脚本会自动配置好所有环境。
4.  完成后，在项目根目录会生成一个 **`run_demo.sh`**。
5.  运行 `./run_demo.sh` 即可体验标准开发流程。
6.  如果您希望按需生成 Python 示例脚本，可运行：
    ```bash
    .venv/bin/python python/gen_example.py
    ```
    生成器支持多选示例类型、修改默认 Model ID，并可在缺少 `ARK_API_KEY` 时提示输入并选择写入项目根目录 `.env`。

---

## 4. 技术原理解析

### 阶段一（零依赖脚本）
当您看到“调用成功”或拿到图片 / 视频 / 向量摘要结果时，说明您已经完成了一次真实的方舟能力调用。
脚本自动完成了以下步骤：
1.  **读取凭证**：读取环境变量 `ARK_API_KEY`，或提示您手动输入。
2.  **选择能力**：根据您选择的能力，决定调用文本、图片、视频、向量化或工具调用接口。
3.  **接收 Prompt**：展示默认 Prompt，并允许您在运行时直接覆盖。
4.  **发送请求**：使用系统自带的网络工具（Windows 的 PowerShell 或 macOS 的 Curl）向方舟服务器发送请求。
5.  **解析结果**：根据能力类型分别提取文本、图片 URL、视频任务状态 / 视频 URL 或向量摘要结果。

### 阶段二（专业开发环境）
当您运行 `setup_windows.bat` 或 `setup_mac.sh` 后，您的项目文件夹中多了一个 `.venv` 文件夹。
这是一个**虚拟环境 (Virtual Environment)**。它包含了 Python 解释器和方舟 SDK。
*   **优势**：无论您系统里安装了何种 Python 版本，该目录下的环境始终是纯净、稳定、可用的。
*   **后续建议**：您可以下载 [VS Code](https://code.visualstudio.com/)，打开本项目文件夹，VS Code 会自动识别到该虚拟环境，您即可像专业工程师一样开始编写代码。

---

## 5. 常见问题

**Q: 双击 `run_windows.bat` 后窗口一闪而过怎么办？**
A: 请尝试右键点击 `run_windows.bat`，选择“以管理员身份运行”。或者先打开 CMD 命令行，拖入 `run_windows.bat` 文件运行，查看具体报错信息。

**Q: Windows 上如果看到 PowerShell 中文乱码，或者报 `Unexpected token`、`The string is missing the terminator` 怎么办？**
A: 这通常意味着您使用的是旧包，里面的 Windows PowerShell 脚本编码不兼容当前环境。请重新下载最新的 `ark_quickstart_package.zip` 后再解压运行。当前发布包中的 Windows `.ps1` 已统一为 `UTF-8 BOM + CRLF`，`.bat` 已统一为 `ASCII + CRLF`。

**Q: Mac 提示“Permission denied”？**
A: 请打开终端，输入 `chmod +x `（注意最后有个空格），然后将 `run_mac.command` 文件拖入终端，按回车。这会赋予文件运行权限。

**Q: 报错“API Key 无效”？**
A: 请检查您输入的 Key 是否完整，是否包含多余的空格。建议直接从控制台复制粘贴。脚本当前兼容历史 UUID 格式与新格式 `ark-<uuid>-<suffix>`；如果本地未识别到格式，也会继续尝试调用，最终以服务端返回结果为准。

**Q: 为什么我选择图片 / 视频 / 向量化后调用失败？**
A: 这通常意味着对应模型尚未开通，或者当前账号暂无权限。请先在控制台开通相应模型后再试。

**Q: 为什么视频生成会等更久？**
A: 视频生成是异步任务。脚本会先创建任务，再轮询状态，因此您会看到 `queued`、`running` 等提示，这是正常现象。

**Q: 一直是 `running`，但没有马上打印视频链接怎么办？**
A: 这通常表示视频任务还没完成，而不是脚本出错。当前脚本默认每 `30` 秒轮询一次，最多轮询 `40` 次；如果任务仍未完成，会打印任务 ID、状态查询地址，以及可直接复制的手动查询命令。您也可以按需调整轮询参数后重试：
*   **macOS/Linux**:
    ```bash
    export ARK_VIDEO_POLL_MAX_ATTEMPTS=40
    export ARK_VIDEO_POLL_INTERVAL_SECONDS=30
    bash scripts/zero_dependency/mac/quickstart.sh
    ```
*   **Windows PowerShell**:
    ```powershell
    $env:ARK_VIDEO_POLL_MAX_ATTEMPTS = "40"
    $env:ARK_VIDEO_POLL_INTERVAL_SECONDS = "30"
    .\scripts\zero_dependency\windows\quickstart.ps1
    ```

---

## 6. 下一步

您已经成功迈出了第一步！接下来，您可以：

*   **继续体验更多能力**：重新运行脚本，在能力菜单中切换到图片生成、视频生成、多模态向量化或工具调用。
*   **修改 Prompt**：脚本运行时会直接展示默认 Prompt，您无需编辑源码文件即可替换成自己的输入。
*   **配置环境变量**：建议先配置 `ARK_API_KEY`，这样后续运行脚本时无需重复输入密钥。
*   **学习更多**：查看 [标准版快速入门](./quickstart_all.md) 了解更多代码细节和进阶用法。
*   **浏览模型**：访问 [模型广场](https://console.volcengine.com/ark/region:ark+cn-beijing/model) 查看更多可用的强大模型。

### 自动化验收脚本

如果您需要重复执行真实交互验收，可以直接运行项目内置的自动化脚本：

*   **统一入口（推荐）**：
    *   macOS/Linux:
        ```bash
        verification/e2e/run_all.sh
        ```
    *   Windows:
        ```bat
        .\verification\e2e\run_all.bat
        ```
*   **macOS/Linux**:
    ```bash
    verification/e2e/mac_zero_dependency_full_flow.expect
    ```
*   **Windows PowerShell**:
    ```powershell
    .\verification\e2e\windows_zero_dependency_full_flow.ps1
    ```

运行前请确保已配置 `ARK_API_KEY`。其中 Windows 自动化脚本需要在可用的 PowerShell 环境中执行。

兼容说明：旧入口 `scripts/e2e/run_all.sh` 与 `scripts/e2e/run_all.bat` 目前仍可继续使用，但它们只作为兼容壳脚本存在，后续请优先使用 `verification/e2e/` 下的新路径。
