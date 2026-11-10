# SnapFix Demo Video Script

**Course:** COMP7506 Group Project  
**Target duration:** 2:50  
**Hard limit:** Under 3:00  
**Format:** Real simulator/app recording + short title cards + English narration and subtitles  
**Version basis:** Current integrated Solo mainline with Qwen, real manual corpus, repair status, and editable reports

## 1. Creative direction

The video should feel like a real product demonstration rather than a generic AI advertisement. Use actual app operations as evidence, with short title cards only to establish the problem and conclude the architecture.

The core story is:

> **A photo is not treated as a final answer. SnapFix checks image quality, extracts visible evidence, retrieves manuals, applies safety rules, and helps the user repair or report.**

不要把视频剪成单纯功能罗列。重点展示三个可信点：

1. 型号或依据不足时，不编造 DIY。
2. 步骤能追溯到真实手册 chunk、原文和 PDF 页码。
3. 高危设备会拒答，并直接进入报修闭环。

## 2. Timeline and narration

### 00:00–00:12 — Opening: the user problem

**Visual:** Use a clean SnapFix title card, followed by the home screen. Optional: 1–2 seconds of appliance close-ups, but do not replace real app evidence with stock footage.

**On-screen text:**

```text
Something stopped working.
What should you do next?
```

**Narration:**

> When an appliance stops working, the hardest part is often not the repair itself. It is knowing what the problem is, whether it is safe to fix, and what to tell a technician. SnapFix turns a photo into a clear next step.

**Production note:** 前 12 秒不要加入复杂品牌动画；尽快进入真实 App。

---

### 00:12–00:42 — Photo diagnosis and honest uncertainty

**Visual:** Select the router photo from the library. Show the preview, start diagnosis, and keep the analysis page visible briefly. Show the Qwen result with the identified router and visible red indicator.

**On-screen text:**

```text
Real visual input. Visible evidence only.
```

**Narration:**

> SnapFix starts with image-quality checks, then uses Qwen3-VL to extract the appliance, labels, error codes, and visible symptoms. It does not need to guess an exact model. If the model or supporting manual cannot be confirmed, SnapFix says so and avoids improvised repair instructions.

**Production note:** 当前真实路由器流程可能因型号不明确而转专业处理，这是有意设计的安全行为，不要使用旧 mock 画面冒充当前真实结果。

---

### 00:42–01:18 — Manual-grounded repair steps

**Visual:** Open error-code lookup. Enter `Bosch` and `E24`. Show the generated decision and steps. Expand a source to reveal the original chunk, PDF page, and chunk ID. Mark one step done, then tap again to undo.

**On-screen text:**

```text
Every real step has a source.
```

**Narration:**

> For an error-code query, SnapFix retrieves relevant sections from a real manual corpus using BM25. Each generated step must cite an exact chunk returned by retrieval. The user can inspect the original excerpt and PDF page, then track or undo progress. A missing or invalid citation means the step is withheld.

**Production note:** 如果一次录屏无法同时拍清步骤和原文，可拆成两个连续镜头，不要缩小到无法阅读。

---

### 01:18–01:43 — Safety refusal and professional help

**Visual:** Select the microwave photo. Show the safety page, with no DIY steps. Emphasize the professional-help message and the repair-request button.

**On-screen text:**

```text
High-risk repair? No DIY steps.
```

**Narration:**

> Safety is enforced by deterministic rules, not left to the model’s discretion. High-risk appliances are stopped before generation, and generated steps are checked again for dangerous operations. For a microwave, SnapFix provides no disassembly instructions and directs the user to qualified help.

**Production note:** 镜头应停留在“没有 DIY 步骤”和报修入口，不需要展示任何危险操作。

---

### 01:43–02:17 — Editable bilingual repair request

**Visual:** From the diagnosis or safety page, open the repair-request sheet. Switch between Chinese and English. Add a short availability note, save the draft, and show copy/share controls.

**On-screen text:**

```text
From diagnosis to a clear repair request.
```

**Narration:**

> When professional help is needed, the diagnosis becomes a structured repair request. It includes the device, error code, observed issue, possible cause, attempted steps, and safety notes. The user can edit and save either language version before copying or sharing it. Photos are attached manually, so the app never claims they were included automatically.

**Production note:** 报修编辑内容只写演示信息，例如 `Available after 6 PM`，不要出现真实地址、电话或邮箱。

---

### 02:17–02:36 — Archive and repair status

**Visual:** Open History. Show a record with an error code, summary, relative time, and progress. Change or display a status such as investigating, awaiting repair, or resolved, then show the archive filters.

**On-screen text:**

```text
Repair progress stays with your account.
```

**Narration:**

> SnapFix also keeps the repair journey after the first diagnosis. Steps, feedback, editable reports, and repair status are saved under the user’s account, making it possible to continue an earlier repair instead of starting again.

---

### 02:36–02:50 — Architecture and closing

**Visual:** Show `docs/assets/architecture.png` briefly, then end on the SnapFix title card.

**On-screen text:**

```text
SnapFix
Real AI. Real manuals. Clear next steps.
```

**Narration:**

> SnapFix combines multimodal AI, real manual evidence, and deterministic safety in one practical workflow. Snap it. Fix it. Or report it—safely.

## 3. Recording plan

### Before recording

- [ ] Use the same commit for all app recordings and architecture assets.
- [ ] Start the backend and confirm `/api/health` reports `provider=qwen` for live recording.
- [ ] Use a demo account and remove personal names, email addresses, and unrelated history.
- [ ] Prepare router, Bosch E24, microwave, report, and archive data in advance.
- [ ] Hide API keys, terminal output, OAuth tokens, and personal notifications.
- [ ] Remove the simulator window frame and desktop distractions from the final crop.
- [ ] Check that English text is readable at the final video resolution.

### Recording rules

- Record each scene separately; do not depend on one perfect continuous take.
- Keep the analysis page only long enough to communicate the process.
- Do not accelerate a result so much that the user cannot read it.
- Do not mix old mock screenshots with current live behavior without a visible explanation.
- If mock mode is used, keep the demo label visible and identify the mode in the narration or notes.
- Do not show unsupported DIY steps merely to make the demo look more capable.

## 4. Editing and audio

- Use English narration with clear English subtitles.
- Add a short title card at the beginning and end, not a full presentation deck.
- Use simple cuts and short zooms only when they improve readability.
- Keep background music below speech and avoid copyrighted tracks.
- Export as MP4 with H.264 video and AAC audio.
- Recommended output: 1920×1080 or higher, with the phone UI remaining legible.

## 5. Final acceptance checklist

- [ ] Duration is **under 180 seconds**, with a target of approximately 170 seconds.
- [ ] The video demonstrates real functionality, not only static mockups.
- [ ] Qwen/mock claims match the mode used in each recording.
- [ ] Photo diagnosis, manual evidence, safety refusal, reporting, and archive are all shown.
- [ ] No personal information, credentials, keys, or private notifications are visible.
- [ ] No desktop video-player controls or simulator information appear in the final video.
- [ ] Narration and subtitles are synchronized and understandable without audio.
- [ ] The exported MP4 plays from beginning to end without errors.
