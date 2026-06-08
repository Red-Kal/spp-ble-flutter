/**
 * BLE 调试日志服务器
 * ===================
 * 接收 Flutter App 发来的日志，提供网页实时查看
 *
 * 启动: node server.js
 * 访问: http://192.168.0.10:3322
 */

const express = require("express");
const app = express();
const PORT = 3322;

// ─── 日志存储 ──────────────────────────────────────────────
const MAX_LOGS = 5000;
const logs = [];
let sseClients = []; // SSE 客户端

// ─── 中间件 ────────────────────────────────────────────────
app.use(express.text({ type: "text/plain", limit: "10mb" }));
app.use(express.json({ limit: "10mb" }));
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(200);
  next();
});

// ─── 工具函数 ──────────────────────────────────────────────
function addLog(level, tag, message, data) {
  const entry = {
    id: logs.length + 1,
    time: new Date().toISOString(),
    level,
    tag,
    message,
    data: data || null,
  };
  logs.push(entry);
  if (logs.length > MAX_LOGS) logs.shift();

  // 推送给所有 SSE 客户端
  const payload = `data: ${JSON.stringify(entry)}\n\n`;
  sseClients.forEach((res) => res.write(payload));

  // 控制台输出
  const ts = entry.time.slice(11, 23);
  console.log(`[${ts}][${level.padEnd(5)}][${tag}] ${message}`);
  return entry;
}

function getTimeAgo(iso) {
  const ms = Date.now() - new Date(iso).getTime();
  if (ms < 1000) return "刚刚";
  if (ms < 60000) return `${Math.floor(ms / 1000)}秒前`;
  if (ms < 3600000) return `${Math.floor(ms / 60000)}分钟前`;
  return `${Math.floor(ms / 3600000)}小时前`;
}

// ─── API 路由 ──────────────────────────────────────────────

// POST /log - App 发送日志
app.post("/log", (req, res) => {
  const { level, tag, message, data } = req.body || {};
  if (!message) return res.status(400).json({ error: "message required" });
  addLog(level || "INFO", tag || "APP", message, data);
  res.json({ ok: true, id: logs.length });
});

// GET /api/logs - 获取历史日志
app.get("/api/logs", (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 200, 1000);
  const level = req.query.level;
  let result = logs;
  if (level) result = result.filter((l) => l.level === level.toUpperCase());
  res.json(result.slice(-limit));
});

// GET /api/stats - 统计
app.get("/api/stats", (req, res) => {
  const stats = { total: logs.length };
  ["DEBUG", "INFO", "WARN", "ERROR"].forEach((l) => {
    stats[l] = logs.filter((e) => e.level === l).length;
  });
  if (logs.length > 0) {
    stats.firstLog = logs[0].time;
    stats.lastLog = logs[logs.length - 1].time;
  }
  res.json(stats);
});

// GET /events - SSE 实时推送
app.get("/events", (req, res) => {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  res.write(`data: ${JSON.stringify({ type: "connected", total: logs.length })}\n\n`);
  sseClients.push(res);
  req.on("close", () => {
    sseClients = sseClients.filter((c) => c !== res);
  });
});

// ─── 网页界面 ──────────────────────────────────────────────
app.get("/", (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BLE 日志服务器</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:-apple-system,sans-serif; background:#0f1117; color:#e1e4f0; padding:20px; }
  .header { display:flex; justify-content:space-between; align-items:center; margin-bottom:16px; flex-wrap:wrap; gap:8px; }
  .header h1 { font-size:20px; }
  .stats { display:flex; gap:12px; font-size:13px; }
  .stats span { padding:2px 10px; border-radius:4px; }
  .stat-total { background:#1a1d2e; }
  .stat-info { background:#1a2e3a; color:#4fc3f7; }
  .stat-warn { background:#2e2a1a; color:#ffb74d; }
  .stat-error { background:#2e1a1a; color:#ef5350; }
  .filters { display:flex; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
  .filters button { background:#1a1d2e; border:1px solid #2a2d3e; color:#e1e4f0; padding:4px 14px; border-radius:6px; cursor:pointer; font-size:12px; }
  .filters button.active { background:#4f8cff; border-color:#4f8cff; }
  .filters button:hover { background:#25283a; }
  .clear-btn { margin-left:auto; background:#2e1a1a !important; border-color:#5a2a2a !important; }
  .clear-btn:hover { background:#4a2a2a !important; }
  .logs { font-family:'Cascadia Code','Fira Code','Consolas',monospace; font-size:12px; line-height:1.6; }
  .log { padding:3px 8px; border-radius:3px; margin:1px 0; display:flex; gap:8px; }
  .log:hover { background:#1a1d2e; }
  .log-time { color:#888c9e; min-width:80px; flex-shrink:0; }
  .log-level { min-width:48px; font-weight:bold; flex-shrink:0; }
  .log-tag { color:#a78bfa; min-width:60px; flex-shrink:0; }
  .log-msg { word-break:break-all; }
  .log-DEBUG .log-level { color:#888c9e; }
  .log-INFO .log-level { color:#4fc3f7; }
  .log-WARN .log-level { color:#ffb74d; }
  .log-ERROR .log-level { color:#ef5350; }
  .log-ERROR { background:#1e1212; }
  .log-data { color:#888c9e; font-size:11px; margin-left:16px; white-space:pre-wrap; }
  .footer { margin-top:20px; font-size:12px; color:#555; text-align:center; }
</style>
</head>
<body>
<div class="header">
  <h1>📡 BLE 日志服务器</h1>
  <div class="stats" id="stats">
    <span class="stat-total">总计: <b id="statTotal">0</b></span>
    <span class="stat-info">INFO: <b id="statInfo">0</b></span>
    <span class="stat-warn">WARN: <b id="statWarn">0</b></span>
    <span class="stat-error">ERROR: <b id="statError">0</b></span>
  </div>
</div>
<div class="filters">
  <button class="active" data-filter="all">全部</button>
  <button data-filter="DEBUG">DEBUG</button>
  <button data-filter="INFO">INFO</button>
  <button data-filter="WARN">WARN</button>
  <button data-filter="ERROR">ERROR</button>
  <button class="clear-btn" onclick="clearLogs()">清空显示</button>
</div>
<div class="logs" id="logs"></div>
<div class="footer">BLE Log Server v1.0 — 监听端口 ${PORT}</div>

<script>
const logsEl = document.getElementById("logs");
let currentFilter = "all";
let logCount = 0;

// 初始化统计
["total", "INFO", "WARN", "ERROR"].forEach(k => {
  document.getElementById("stat" + k).textContent = "0";
});

// 筛选按钮
document.querySelectorAll(".filters button[data-filter]").forEach(btn => {
  btn.onclick = () => {
    document.querySelectorAll(".filters button[data-filter]").forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    currentFilter = btn.dataset.filter;
    applyFilter();
  };
});

function applyFilter() {
  logsEl.querySelectorAll(".log").forEach(el => {
    if (currentFilter === "all") { el.style.display = "flex"; return; }
    el.style.display = el.classList.contains("log-" + currentFilter) ? "flex" : "none";
  });
}

function addLogToPage(entry) {
  const div = document.createElement("div");
  div.className = "log log-" + entry.level;
  const time = entry.time.slice(11, 23);
  div.innerHTML = \`
    <span class="log-time">\${time}</span>
    <span class="log-level">\${entry.level}</span>
    <span class="log-tag">[\${entry.tag}]</span>
    <span class="log-msg">\${escapeHtml(entry.message)}</span>
    \${entry.data ? '<div class="log-data">' + escapeHtml(JSON.stringify(entry.data, null, 2)) + '</div>' : ''}
  \`;
  logsEl.appendChild(div);
  logCount++;

  // 保持最新500条
  while (logsEl.children.length > 500) logsEl.removeChild(logsEl.firstChild);

  // 自动滚到底
  window.scrollTo(0, document.body.scrollHeight);

  // 筛选
  if (currentFilter !== "all" && !div.classList.contains("log-" + currentFilter)) {
    div.style.display = "none";
  }
}

function escapeHtml(text) {
  const d = document.createElement("div");
  d.textContent = text;
  return d.innerHTML;
}

function clearLogs() {
  logsEl.innerHTML = "";
  logCount = 0;
}

// SSE 实时接收
const evtSource = new EventSource("/events");
evtSource.onmessage = (e) => {
  try {
    const data = JSON.parse(e.data);
    if (data.type === "connected") return;
    addLogToPage(data);

    // 更新统计
    fetch("/api/stats").then(r => r.json()).then(s => {
      document.getElementById("statTotal").textContent = s.total;
      document.getElementById("statInfo").textContent = s.INFO;
      document.getElementById("statWarn").textContent = s.WARN;
      document.getElementById("statError").textContent = s.ERROR;
    }).catch(() => {});
  } catch(_) {}
};

// 加载历史日志
fetch("/api/logs?limit=200").then(r => r.json()).then(data => {
  data.forEach(addLogToPage);
  window.scrollTo(0, document.body.scrollHeight);
}).catch(() => {});
</script>
</body>
</html>`);
});

// ─── 启动 ──────────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  console.log("=".repeat(50));
  console.log("  BLE 日志服务器已启动");
  console.log(`  本地访问: http://192.168.0.10:${PORT}`);
  console.log(`  本机访问: http://localhost:${PORT}`);
  console.log("=".repeat(50));
});
