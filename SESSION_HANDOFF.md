# Session Handoff — Unitree G1 EDU U4 Training Preparation

**Written:** 2026-07-15 · **Author:** Claude Code (Opus 4.8) · **Purpose:** hand this session's work to a brand-new chat with no prior context.
**Updated:** 2026-07-15 by a follow-up session (Claude Fable 5) — lab quick-reference delivered, Excel move re-attempted and still blocked. Sections 4, 6, and 12 reflect the new state.

> **Read this first:** the work described here does **not** live in this folder. This handoff file sits in `C:\Users\Admin\Desktop\AI News` (an unrelated daily-automation repo) only because that was the session's working directory. **All actual deliverables are in `C:\Users\Admin\Desktop\Robot`**, which is not a git repository.

---

## 1. Project goal

The user was assigned to study a set of GitHub repositories and extract the ones useful for **training a Unitree G1 EDU U4 humanoid robot**, collecting them in a folder with a table of links. That original task is **complete**. The session then expanded — at the user's request — into building a full training-preparation package for the team who will do the actual training.

**Hard constraint that shaped everything:** the user has **no access to the physical robot and no access to the training hardware** — only to the public repositories. Every deliverable was therefore derived from repository contents plus public GitHub/vendor pages. Nothing was run against a robot; nothing could be.

**Audience for the deliverables:** the engineers who will train the robot (not the user personally). The user is coordinating/preparing, not operating the robot.

---

## 2. The robot (established facts)

"Unitree G1 EDU U4" is a complete, valid designation: **G1** = robot line, **EDU** = developer edition (SDK access — this is what makes the repos usable), **U4** = configuration package.

Per retailer spec pages (checked 2026-07-14), **U4 = "EDU Ultimate B"**:

| Property | Value |
|---|---|
| Degrees of freedom | **29-DoF body** (3-DoF waist, full wrists) — matches `unitree_rl_lab`'s ready-made `G1-29dof` environment |
| Hands | **Dex3-1 with tactile sensors** (this is what distinguishes U4 from U3) |
| Onboard compute | NVIDIA Jetson Orin NX 16GB (100 TOPS) |
| LiDAR | **Livox MID-360** (built in — this is exactly the lidar the WK repo requires) |
| Depth camera | Intel RealSense D435i |

⚠️ **Still unverified on the physical unit.** This comes from retailer pages, not the robot. Package contents can vary by order. Confirming the DoF variant physically is the single highest-value action for the team, because a 23-vs-29-DoF mismatch **breaks sim-to-real silently** (no loud error — just policies that fail on hardware).

---

## 3. Key decisions made (and why)

| Decision | Rationale |
|---|---|
| **Clones are frozen, never auto-updated** | The docs describe specific commits; auto-updating would silently invalidate them and could pull breaking upstream changes (precedent: IsaacLab 2.3.2 broke `unitree_rl_lab`). Updates must be deliberate human decisions. |
| **Upstream watch reports, does not sync** | Same reason. It appends news to a file; it never touches `repos\`. |
| **Shallow clones (`--depth 1`)** | Size. ~2.1 GB as-is; full history was unnecessary for reading/installing. |
| **Docs moved into `docs\`** | The user found ten loose files at the folder root too scattered. |
| **WK classified as reference, not a training tool** | It is a navigation/voice *application*, not RL/IL. Audited rather than recommended. |
| **Slide deck + "first contact" script deliberately skipped** | The deck only matters if presenting rather than handing over a folder; the connectivity script is better written by whoever has the Linux machine and robot in front of them (SDK examples in `repos\unitree_sdk2_python\example\`). |
| **Excel built via Office COM automation** | No Python/pip on this machine; Word and Excel COM are available and were verified working. |

---

## 4. Deliverables — current state (all verified on disk 2026-07-15)

```
C:\Users\Admin\Desktop\Robot\
├── README.md                          ← index / entry point, incl. 3 top warnings
├── Unitree-G1-Training-Repos.xlsx     ← ⚠️ still at root; belongs in docs\ (see §6)
├── ~$Unitree-G1-Training-Repos.xlsx   ← Excel lock file (proves it's still open)
├── .vscode\                           ← not created by this session
├── docs\
│   ├── lab-quick-reference.md             printable one-page wall sheet (added 2026-07-15)
│   ├── repo-evaluation-unitree-g1.md      the original task's deliverable
│   ├── setup-guide.md                     ordered day-one install, both pipelines
│   ├── dependency-compatibility-matrix.md OS/Python/CUDA reqs + conflict analysis
│   ├── g1-technical-reference.md          joints, limits, gains, DDS interface
│   ├── data-format-and-storage.md         episode format, LeRobot conversion, disk math
│   ├── known-issues-and-workarounds.md    ~30 pitfalls mined from issue trackers
│   ├── wk-audit.md                        safety/code audit of third-party WK
│   ├── version-snapshot.md                frozen commit hashes
│   └── upstream-watch.md                  auto-appended weekly upstream news
├── scripts\
│   ├── check-upstream.ps1                 the weekly watcher (read-only)
│   └── upstream-watch-state.json          last-check timestamp
└── repos\                             11 shallow clones, ~2.1 GB
```

Each document is standalone prose with tables; every factual claim cites the source file path inside `repos\` (or an issue URL).

---

## 5. Frozen repository snapshot (cloned 2026-07-14)

Also recorded in `docs\version-snapshot.md`. Restore any repo to the analyzed state with `git checkout <commit>`.

| Repository | Commit | Role |
|---|---|---|
| xr_teleoperate | `7dc9aa1a6edbf4a9f4f887d8ab6fc449ea5135f6` | **IL:** XR-headset teleop + demo recording |
| unitree_rl_lab | `4960b84732b0c2ec593dccbfe963fda1bcd7b1e3` | **RL:** current official stack (IsaacLab + RSL-RL) |
| unitree_lerobot | `41c2805742de879ddab2d8d6beaeaf215f876395` | **IL:** trains policies from recorded demos |
| unitree_sim_isaaclab | `e30c25b1dffdf92ada1d6c8c1fe9a47bdde0fecc` | simulated practice / data collection |
| unitree_mujoco | `ae6a8403e272733e9996ef59990880330496177f` | sim-to-sim validation gate |
| unitree_rl_mjlab | `1425b15f73bd4095f0df53709d7c389c3eb9e790` | RL alternative without Isaac-capable GPU |
| unitree_rl_gym | `276801e46c5d433564f24658bac64f254b7d2d4b` | **legacy** — reading material only |
| unitree_sdk2 | `21d0a3b2c46ee48c8fdf2783becb6be3beb0a59b` | C++ SDK — real-robot deployment |
| unitree_sdk2_python | `e4cd91f051aaa77a70600e3d2bf7f50889db1980` | Python SDK — dependency of teleop stack |
| unitree_model | `b6a8942b0803b6c137e58cef12beb4b03e4a2fa7` | URDF/MJCF/USD robot models |
| WK (Dailywatero) | `1e88d434bfa2481242e540dbed10f95521f525b3` | **third-party** — reference only, see audit |

**Clone quirks a new session must know:**
- `xr_teleoperate` submodules (`televuer`, `teleimager`) are **empty folders** — shallow clone skipped them. Fix: `git submodule update --init --depth 1` inside the repo.
- `unitree_lerobot` STL meshes are **Git-LFS pointers**, not real files (Git LFS not installed here). Code/docs complete. Fix if needed: `git lfs pull`.
- No commit history in the clones (shallow).

---

## 6. Remaining tasks

**Completed since this handoff was written (2026-07-15, follow-up session):**
- **Printable one-page lab quick-reference** — DONE. Created `docs\lab-quick-reference.md`: U4 config summary (with the verify-DoF warning), network table (wired-only, host static IP, PC2 at .164, exact-NIC-name rule, domain_id 0-vs-1, `unitree_hg` not `unitree_go`), hard version pins, controller/teleop keys (L2+R2 debug, L2+Up stand, r/s/q, right-A exit, both-joysticks soft e-stop), and a checkbox pre-hardware-run safety list. All facts sourced from the existing docs, not re-derived. Also added a row for it to the README's document table.

**Open / blocked:**
1. **Move `Unitree-G1-Training-Repos.xlsx` into `docs\`** — still blocked as of 2026-07-15 (follow-up session): re-attempted the move, failed again with "process cannot access the file"; `Get-Process EXCEL` confirmed Excel PID 13100 open since 09:08 with window title "Unitree-G1-Training-Repos - Excel". Force-closing the user's Excel remains deliberately avoided. After the move, fix the one link in `README.md` (currently `[Unitree-G1-Training-Repos.xlsx](Unitree-G1-Training-Repos.xlsx)` → `docs/...`). The `~$` lock file disappears once Excel closes.

**Offered, user has not yet accepted (all optional, low effort):**
2. **DoF/end-effector identification guide** — now much shorter since the U4 spec lookup answered most of it; would only cover physical confirmation steps.
3. **Handoff zip** — docs-only (~few hundred KB, emailable) and/or full (~2 GB with clones).

**Explicitly out of scope** (see §3): slide deck, first-contact connectivity script.

**Genuinely exhausted:** further repo-mining has diminishing returns. Everything still undone needs the robot, the team, or the training hardware — none of which are available to this user.

---

## 7. The automation that is now running

**Scheduled task `Robot Upstream Watch`** — verified registered, State: `Ready`, **next run 2026-07-20 09:00** (weekly, Mondays 09:00). Never yet fired on schedule; the report file exists from a manual test run.

- **Runs:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Admin\Desktop\Robot\scripts\check-upstream.ps1"`
- **Does:** queries the GitHub API for all 11 repos, appends a dated section to `docs\upstream-watch.md` listing new commits + most-discussed issues since the last check. Quiet repos get a one-line "no activity" note, so a quiet week still proves the check ran.
- **Never does:** modify `repos\`. Strictly read-only. Reports; does not sync.
- **State:** `scripts\upstream-watch-state.json` holds the last-check timestamp so each run only reports what's new.
- **Caveat:** if the PC is off/asleep at Monday 09:00, that week is skipped (missed-run catch-up was offered but not implemented). A Windows toast notification on changes was also offered, not implemented.

**Test-run findings (2026-07-14):** 10 repos quiet; `unitree_lerobot` had genuine same-day issue activity, incl. a closed issue on running eval on the G1 EDU's onboard Development Unit — directly relevant to the team.

**Two bugs were found and fixed during that test** (a new session editing this script should not reintroduce them):
- **Em-dashes in the script body** caused PowerShell 5.1 parse errors (encoding). All replaced with ASCII hyphens. Keep the script ASCII-only.
- **Phantom commits:** in PS 5.1, `@(...)` around an empty JSON API response yields `@($null)` — length 1 — so every quiet repo falsely reported "1 new commit". Fixed by explicit `Where-Object { $null -ne $_ }` filtering. The first generated report was bogus and was deleted and regenerated.

---

## 8. Technical facts worth not re-deriving

**The two pipelines:**
- **RL (locomotion / body skills):** `unitree_rl_lab` (train in Isaac Sim) → `unitree_mujoco` (sim-to-sim validate) → `unitree_sdk2` (deploy).
- **IL (manipulation / hand-arm tasks):** `xr_teleoperate` (record demos) → `unitree_lerobot` (train) → `unitree_sdk2_python` (deploy). Practice in `unitree_sim_isaaclab` first.

**Environment:** Ubuntu 22.04 + NVIDIA RTX GPU (driver ≥525). Windows unsupported by this stack. The stacks **cannot share one Python environment** — Python splits 3.8 (`unitree_rl_gym`) / 3.10 (`xr_teleoperate`, `unitree_lerobot` requires <3.11) / 3.11 (`unitree_rl_mjlab`, Isaac Sim 5.x); torch pins diverge (2.3.1+cu121 vs 2.5.1/2.7.0); `logging_mp==0.1.5` vs `==0.2.1` clash directly; `numpy==1.20` (rl_gym) is irreconcilable with 1.26.4 elsewhere. **Recommendation: 5–6 conda envs on one Ubuntu 22.04 RTX workstation**, plus the robot's onboard PC2 (Ubuntu 20.04, runs `teleimager` camera streaming during teleop). WK needs ROS 1 Noetic/Ubuntu 20.04 — incompatible with the training box.

**Hard version pins (violating these costs days):** Isaac Sim **5.1.0** + IsaacLab **2.3.0** exactly (**2.3.2 is confirmed broken**); Python **3.10** for SDK/teleop; Pinocchio **3.1.0**; `unitree_sdk2_python` ≥ commit `404fe44`; vuer ≥ 0.0.67. ROS 2's CycloneDDS conflicts with `unitree_sdk2` in one environment (`free(): invalid pointer`).

**Robot interface:** policies run at **50 Hz** (dt 0.005, decimation 4). DDS topics `rt/lowcmd` / `rt/lowstate` (low-level), `rt/arm_sdk` (arms only, safer). **Message types are `unitree_hg`, NOT `unitree_go`** — the Go2's IDL compiles fine and then fails against the G1; this trips people up constantly. Robot subnet **192.168.123.x** (set PC static, e.g. `192.168.123.222/24`); **wired Ethernet only** — DDS/network misconfiguration is the single most common failure mode across all repos' issue trackers; always pass the exact NIC name to `ChannelFactoryInitialize`. LowCmd has 35 motor slots regardless of variant (the 23-DoF MJCF keeps dummy joints for index compatibility); 23-DoF deploy additionally requires motor `mode=1`. Sim and real robot can collide on the same DDS **domain_id** — separate them, or sim commands can reach the physical robot.

**Data (IL):** recording at 30 Hz; up to 4 camera streams as 640×480 JPEGs + one `data.json` per episode (arm/hand joint states). ~**0.5 GB per raw episode** → **~100–120 GB per 200-episode task** (~6–8 GB after LeRobot MP4 conversion). Need ~100–200 episodes per task; **quality beats quantity** — weak/looping policies trace to data problems; replay datasets before training. Converter has **fps=30 hard-coded**. `data_editor` trims bad segments (cheaper than re-recording). Trainable policies: ACT (standard starting point), Diffusion, Pi0, Pi0.5, GR00T.

**Misc:** in `unitree_model`, `_rev_1_0` filenames = current hardware revision — use those. `unitree_rl_lab` also has motion-imitation ("mimic") tasks needing a `.npz` preprocessing step. Hands are separate subsystems with their own driver repos (`dex1_1_service`, `dfx_inspire_service`, `brainco_hand_service`) — U4 ships Dex3-1. Known hardware issue: shoulder motors can overheat during long Inspire-hand teleop sessions. Apple Vision Pro has an **unresolved** WebSocket-disconnect issue — relevant if a headset is still being chosen.

---

## 9. Safety caveats (carry these forward verbatim)

1. **Never run an unvalidated policy on hardware.** MuJoCo sim-to-sim is the gate. If a policy jitters/drifts in MuJoCo it's a config-parity problem (gains, default poses) — **not** "train longer".
2. **First hardware runs:** robot in gantry/harness, clear floor space, e-stop in hand, supervised.
3. **Confirm the DoF variant before training.** Mismatch fails silently.
4. **WK must not be run on the robot unreviewed.** The audit found **no malicious code** — the bundled `unitree_sdk2py` diffs clean against official (older snapshot, 5 trivial line differences), and locomotion uses only the high-level `LocoClient.Move/StopMove` API plus upper-body `LowCmd_` on `rt/arm_sdk`; nothing WK-authored touches `rt/lowcmd`. **But it is demo-grade:** no e-stop, no `/cmd_vel` staleness watchdog (it re-sends the last velocity at 50 Hz if `move_base` dies), no shutdown Damp/StopMove fallback, an unclamped open-loop bridge with TEB configured at **3.0 m/s**, and cloud-LLM voice tools that spawn motion subprocesses **with no human confirmation**. It streams mic audio to external hosts (api.tenclass.net, xiaozhi.me, plus bigmodel.cn, dashscope, amap, kuwo, an opaque api.xiaodaokg.com relay, bing, 12306, weilei.site). `docs\wk-audit.md` ends with a 10-item pre-run checklist.
5. **Do not auto-update the clones.** See §3.

---

## 10. Commands

```powershell
# Run the upstream watch manually (read-only, ~1 min)
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Admin\Desktop\Robot\scripts\check-upstream.ps1"

# Inspect / manage the scheduled task
Get-ScheduledTask -TaskName "Robot Upstream Watch"
Get-ScheduledTaskInfo -TaskName "Robot Upstream Watch"    # NextRunTime
# Unregister-ScheduledTask -TaskName "Robot Upstream Watch" -Confirm:$false   # to remove

# Finish the pending move once Excel is closed (then fix the README link)
Move-Item "C:\Users\Admin\Desktop\Robot\Unitree-G1-Training-Repos.xlsx" "C:\Users\Admin\Desktop\Robot\docs"

# Deliberately adopt an upstream update (per repo), then update docs\version-snapshot.md
cd "C:\Users\Admin\Desktop\Robot\repos\<repo>"; git pull

# Repair the two known clone gaps, if ever needed
cd "C:\Users\Admin\Desktop\Robot\repos\xr_teleoperate"; git submodule update --init --depth 1
cd "C:\Users\Admin\Desktop\Robot\repos\unitree_lerobot"; git lfs pull    # requires Git LFS install
```

**Environment notes for a new session:** Windows 11, PowerShell 5.1 (no `&&`, no ternary, ASCII-only scripts — see §7), Bash tool also available. **No Python/pip installed.** Word + Excel COM automation available and verified. Git LFS not installed. The `Robot` folder is **not** a git repo (the `AI News` folder is, with daily automation — do not entangle the two).

---

## 11. Sources

**The four links the user was originally given:**
- https://github.com/unitreerobotics/xr_teleoperate
- https://github.com/unitreerobotics/unitree_rl_lab
- https://github.com/Dailywatero/WK
- https://github.com/orgs/unitreerobotics/repositories

**U4 configuration (retailer pages, checked 2026-07-14 — not vendor-authoritative):**
- https://robostore.com/products/unitree-g1-edu-ultimate-robotic-humanoid
- https://robostore.com/blogs/news/unitree-g1-edu-ultimate-technical-specifications
- https://futurology.tech/products/unitree-g1-edu-ultimate-b-u4-humanoid-robot-tactile-dexterity

**Other:** the repos' GitHub issue trackers (mined for `docs\known-issues-and-workarounds.md`, ~30 issues with URLs); official Unitree docs at https://support.unitree.com/home/en/G1_developer.

---

## 12. Suggested first message for the new session

> Continue the Unitree G1 EDU U4 training-prep work. Read `C:\Users\Admin\Desktop\AI News\SESSION_HANDOFF.md` first, then `C:\Users\Admin\Desktop\Robot\README.md`. Pending: move the Excel file into `docs\` (was locked by Excel) and fix its README link. The lab quick-reference is done (`docs\lab-quick-reference.md`). Optional remaining: DoF/end-effector physical-confirmation guide, handoff zip.
