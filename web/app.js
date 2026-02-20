/* global GetParentResourceName, fetch */

const state = {
  open: false,
  tab: "home",
  items: [],
  moneyTypes: [],
  jobs: [],
  gangs: [],
  config: {},
  coords: { x: 0, y: 0, z: 0, h: 0, street: "-" },
};

function nuiPost(name, data = {}) {
  const resource = GetParentResourceName ? GetParentResourceName() : "M7MD-tool";
  return fetch(`https://${resource}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  }).catch(() => {});
}

function $(id) {
  return document.getElementById(id);
}

function escapeHtml(s) {
  return String(s || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function showToast(text) {
  const toast = $("toast");
  toast.textContent = text;
  toast.classList.remove("hidden");
  window.clearTimeout(showToast._t);
  showToast._t = window.setTimeout(() => toast.classList.add("hidden"), 1100);
}

function setTab(tab) {
  state.tab = tab;
  document.querySelectorAll(".nav").forEach((b) => b.classList.toggle("active", b.dataset.tab === tab));

  const tabs = ["home", "give", "coords", "inventory", "player", "zones", "debug", "snippets"];
  tabs.forEach((t) => {
    const el = document.getElementById(`tab${t[0].toUpperCase()}${t.slice(1)}`);
    if (el) el.classList.toggle("hidden", t !== tab);
  });

  if (tab === "give") $("give_itemInput").focus();
}

function formatNum(n) {
  return Number(n || 0).toFixed(3);
}

function updateCoords(packet) {
  state.coords = packet || state.coords;
  $("cx").textContent = formatNum(state.coords.x);
  $("cy").textContent = formatNum(state.coords.y);
  $("cz").textContent = formatNum(state.coords.z);
  $("ch").textContent = formatNum(state.coords.h);
  $("cstreet").textContent = state.coords.street || "-";
}

function filterList(query, list) {
  const q = String(query || "").trim().toLowerCase();
  if (!q) return [];
  const out = [];
  for (let i = 0; i < list.length; i++) {
    const it = list[i];
    if (!it || !it.name) continue;
    const name = String(it.name).toLowerCase();
    const label = String(it.label || "").toLowerCase();
    if (name.includes(q) || label.includes(q)) {
      out.push(it);
      if (out.length >= 20) break;
    }
  }
  return out;
}

function attachAutocomplete(inputId, suggId, listGetter) {
  const input = $(inputId);
  const box = $(suggId);

  function render(list) {
    box.innerHTML = "";
    if (!list || list.length === 0) {
      box.classList.add("hidden");
      return;
    }
    list.forEach((it) => {
      const row = document.createElement("div");
      row.className = "suggestion";
      row.innerHTML = `<div class="name">${escapeHtml(it.name)}</div><div class="label">${escapeHtml(
        it.label || ""
      )}</div>`;
      row.addEventListener("click", () => {
        input.value = it.name;
        box.classList.add("hidden");
        input.dispatchEvent(new Event("change"));
      });
      box.appendChild(row);
    });
    box.classList.remove("hidden");
  }

  input.addEventListener("input", () => render(filterList(input.value, listGetter())));
  input.addEventListener("keydown", (e) => {
    if (e.key === "Escape") box.classList.add("hidden");
  });
  document.addEventListener("click", (e) => {
    if (!e.target.closest(`#${suggId}`) && e.target !== input) box.classList.add("hidden");
  });
}

function fillSelect(selectId, values) {
  const sel = $(selectId);
  sel.innerHTML = "";
  (values || []).forEach((v) => {
    const opt = document.createElement("option");
    opt.value = v;
    opt.textContent = v;
    sel.appendChild(opt);
  });
}

function generateSnippet(type, name) {
  const n = String(name || "").trim() || "resource:eventName";

  if (type === "clientEvent") {
    return `RegisterNetEvent('${n}', function(data)\n  -- TODO\nend)\n`;
  }
  if (type === "serverEvent") {
    return `RegisterNetEvent('${n}', function(data)\n  local src = source\n  -- TODO\nend)\n`;
  }
  if (type === "callback") {
    return `-- server\nlib.callback.register('${n}', function(source, arg1)\n  -- TODO\n  return true\nend)\n\n-- client\nlocal ok = lib.callback.await('${n}', false, 'arg1')\n`;
  }
  if (type === "qbCommand") {
    return `-- server (qb-core)\nQBCore.Commands.Add('mycmd', 'help', {}, false, function(source, args)\n  -- TODO\nend, 'admin')\n`;
  }
  if (type === "qbItem") {
    const item = n.includes(":") ? n.split(":").pop() : n;
    const itemName = item || "my_item";
    return `-- qb-core/shared/items.lua\n[\"${itemName}\"] = {\n  [\"name\"] = \"${itemName}\",\n  [\"label\"] = \"${itemName}\",\n  [\"weight\"] = 100,\n  [\"type\"] = \"item\",\n  [\"image\"] = \"${itemName}.png\",\n  [\"unique\"] = false,\n  [\"useable\"] = true,\n  [\"shouldClose\"] = true,\n  [\"combinable\"] = nil,\n  [\"description\"] = \"\",\n},\n`;
  }
  if (type === "qbJob") {
    const job = n.includes(":") ? n.split(":").pop() : n;
    const jobName = job || "myjob";
    return `-- qb-core/shared/jobs.lua\n[\"${jobName}\"] = {\n  [\"label\"] = \"${jobName}\",\n  [\"defaultDuty\"] = true,\n  [\"offDutyPay\"] = false,\n  [\"grades\"] = {\n    [\"0\"] = { [\"name\"] = \"Recruit\", [\"payment\"] = 100 },\n  },\n},\n`;
  }
  return "";
}

function initZonesUI() {
  function setZoneMode(mode) {
    $("zone_poly").classList.toggle("hidden", mode !== "poly");
    $("zone_boxcircle").classList.toggle("hidden", mode === "poly");
  }

  $("zone_mode").addEventListener("change", (e) => {
    const mode = e.target.value;
    setZoneMode(mode);
    nuiPost("m7mdtool_zones", { action: "setMode", mode });
  });

  $("zone_preview").addEventListener("change", (e) => {
    nuiPost("m7mdtool_zones", { action: "togglePreview", enabled: e.target.checked });
  });

  $("zone_addPoint").addEventListener("click", () => nuiPost("m7mdtool_zones", { action: "addPoint" }));
  $("zone_undoPoint").addEventListener("click", () => nuiPost("m7mdtool_zones", { action: "undoPoint" }));
  $("zone_clearPoints").addEventListener("click", () => nuiPost("m7mdtool_zones", { action: "clearPoints" }));

  $("zone_applyParams").addEventListener("click", () => {
    nuiPost("m7mdtool_zones", {
      action: "setParams",
      radius: Number($("zone_radius").value || 3),
      length: Number($("zone_length").value || 3),
      width: Number($("zone_width").value || 3),
      heading: Number($("zone_heading").value || 0),
      minZ: $("zone_minZ").value === "" ? null : Number($("zone_minZ").value),
      maxZ: $("zone_maxZ").value === "" ? null : Number($("zone_maxZ").value),
    });
    showToast("Applied");
  });

  $("zone_copy").addEventListener("click", () => {
    nuiPost("m7mdtool_zones", { action: "copySnippet", snipType: $("zone_snipType").value });
    showToast("Copied");
  });

  setZoneMode($("zone_mode").value);
}

function init() {
  $("closeBtn").addEventListener("click", () => nuiPost("m7mdtool_close"));

  document.querySelectorAll(".nav").forEach((b) => b.addEventListener("click", () => setTab(b.dataset.tab)));
  document.querySelectorAll("[data-goto-tab]").forEach((b) =>
    b.addEventListener("click", () => setTab(b.getAttribute("data-goto-tab")))
  );

  // Autocomplete
  attachAutocomplete("give_itemInput", "give_itemSuggestions", () => state.items);
  attachAutocomplete("rem_itemInput", "rem_itemSuggestions", () => state.items);
  attachAutocomplete("job_name", "job_suggestions", () => state.jobs);
  attachAutocomplete("gang_name", "gang_suggestions", () => state.gangs);

  // Give item
  $("giveBtn").addEventListener("click", () => {
    const itemName = String($("give_itemInput").value || "").trim();
    const amount = Number($("give_amountInput").value || 1);
    const targetRaw = String($("give_targetInput").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    if (!itemName) return showToast("Item required");
    nuiPost("m7mdtool_giveItem", { itemName, amount, targetId });
    showToast("Sent");
  });

  // Remove item
  $("removeBtn").addEventListener("click", () => {
    const itemName = String($("rem_itemInput").value || "").trim();
    const amount = Number($("rem_amountInput").value || 1);
    const targetRaw = String($("rem_targetInput").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    if (!itemName) return showToast("Item required");
    nuiPost("m7mdtool_removeItem", { itemName, amount, targetId });
    showToast("Sent");
  });

  // Clear inventory
  $("clearBtn").addEventListener("click", () => {
    const targetRaw = String($("clr_targetInput").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    const confirm = $("clr_confirm").checked === true;
    nuiPost("m7mdtool_clearInventory", { targetId, confirm });
    showToast(confirm ? "Sent" : "Confirm first");
  });

  // Copy coords buttons
  document.querySelectorAll("[data-copy]").forEach((b) =>
    b.addEventListener("click", () => {
      nuiPost("m7mdtool_copy", { format: b.getAttribute("data-copy") });
      showToast("Copied");
    })
  );
  $("copyPlayerBtn").addEventListener("click", () => {
    nuiPost("m7mdtool_copyPlayerInfo");
    showToast("Copied");
  });
  $("overlayToggle").addEventListener("change", (e) => nuiPost("m7mdtool_toggleOverlay", { enabled: e.target.checked }));

  // Player tools
  $("gotoBtn").addEventListener("click", () => {
    nuiPost("m7mdtool_goto", { targetId: Number($("pl_targetInput").value || 0), confirm: $("pl_confirm").checked });
    showToast("Sent");
  });
  $("bringBtn").addEventListener("click", () => {
    nuiPost("m7mdtool_bring", { targetId: Number($("pl_targetInput").value || 0), confirm: $("pl_confirm").checked });
    showToast("Sent");
  });

  $("moneyBtn").addEventListener("click", () => {
    const moneyType = $("money_type").value;
    const amount = Number($("money_amount").value || 0);
    const targetRaw = String($("money_target").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    nuiPost("m7mdtool_giveMoney", { moneyType, amount, targetId });
    showToast("Sent");
  });

  $("jobBtn").addEventListener("click", () => {
    const jobName = String($("job_name").value || "").trim();
    const grade = Number($("job_grade").value || 0);
    const targetRaw = String($("job_target").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    nuiPost("m7mdtool_setJob", { jobName, grade, targetId });
    showToast("Sent");
  });

  $("gangBtn").addEventListener("click", () => {
    const gangName = String($("gang_name").value || "").trim();
    const grade = Number($("gang_grade").value || 0);
    const targetRaw = String($("gang_target").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    nuiPost("m7mdtool_setGang", { gangName, grade, targetId });
    showToast("Sent");
  });

  $("tpBtn").addEventListener("click", () => {
    nuiPost("m7mdtool_tpCoords", {
      x: Number($("tp_x").value),
      y: Number($("tp_y").value),
      z: Number($("tp_z").value),
      h: Number($("tp_h").value || 0),
      confirm: $("tp_confirm").checked === true,
    });
    showToast("Sent");
  });

  $("metaBtn").addEventListener("click", () => {
    const key = String($("meta_key").value || "").trim();
    const value = String($("meta_value").value || "");
    const targetRaw = String($("meta_target").value || "").trim();
    const targetId = targetRaw === "" ? null : Number(targetRaw);
    const valueIsJson = $("meta_isJson").checked === true;
    if (!key) return showToast("Key required");
    nuiPost("m7mdtool_setMetadata", { key, value, targetId, valueIsJson });
    showToast("Sent");
  });

  $("perm_get").addEventListener("click", async () => {
    const targetId = Number($("perm_target").value || 0);
    if (!targetId) return showToast("Target required");
    const resp = await nuiPost("m7mdtool_getPermission", { targetId });
    const res = resp && resp.json ? await resp.json() : null;

    const list = $("perm_list");
    if (list) list.innerHTML = "";

    if (res && res.current) {
      const current = String(res.current);
      $("perm_current").value = current;

      const all = Array.isArray(res.all) ? res.all : [];
      all.forEach((perm) => {
        const p = String(perm);
        const row = document.createElement("div");
        row.className = "memberRow";
        const isCurrent = p === current;
        row.innerHTML = `
          <div class="memberName">${escapeHtml(p)}</div>
          <div style="display:flex;gap:8px;align-items:center;">
            <div class="pill ${isCurrent ? "on" : ""}">${isCurrent ? "current" : ""}</div>
            <button class="btn" data-perm-set="${escapeHtml(p)}">Set</button>
            <button class="btn dangerBtn" data-perm-remove="${escapeHtml(p)}" ${isCurrent ? "" : "disabled"}>X</button>
          </div>
        `;
        list.appendChild(row);
      });
    } else {
      $("perm_current").value = "-";
      showToast("Failed");
    }
  });

  $("perm_remove").addEventListener("click", () => {
    const targetId = Number($("perm_target").value || 0);
    if (!targetId) return showToast("Target required");
    if (!window.confirm("Remove permission (set user)?")) return;
    nuiPost("m7mdtool_removePermission", { targetId });
    showToast("Sent");
  });

  $("perm_kick").addEventListener("click", () => {
    const targetId = Number($("perm_target").value || 0);
    if (!targetId) return showToast("Target required");
    if (!window.confirm("Kick this player?")) return;
    const reason = String($("perm_kickReason").value || "");
    nuiPost("m7mdtool_kickPlayer", { targetId, reason });
    showToast("Sent");
  });

  document.addEventListener("click", (e) => {
    const btn = e.target && e.target.closest && e.target.closest("[data-perm-remove]");
    const setBtn = e.target && e.target.closest && e.target.closest("[data-perm-set]");
    const targetId = Number($("perm_target").value || 0);
    if (!btn && !setBtn) return;
    if (!targetId) return showToast("Target required");

    if (setBtn) {
      const perm = setBtn.getAttribute("data-perm-set");
      if (!window.confirm(`Set permission to ${perm}?`)) return;
      nuiPost("m7mdtool_setPermission", { targetId, permission: perm });
      showToast("Sent");
      return;
    }

    if (btn) {
      if (btn.hasAttribute("disabled")) return;
      if (!window.confirm("Remove permission (set user)?")) return;
      nuiPost("m7mdtool_removePermission", { targetId });
      showToast("Sent");
    }
  });

  // Debug event tester
  $("ev_btn").addEventListener("click", () => {
    if (!state.config.enableEventTester) return showToast("Disabled");
    nuiPost("m7mdtool_triggerEvent", { eventName: $("ev_name").value, jsonPayload: $("ev_payload").value });
    showToast("Sent");
  });

  // Snippets
  $("snip_gen").addEventListener("click", () => {
    $("snip_out").value = generateSnippet($("snip_type").value, $("snip_name").value);
  });
  $("snip_copy").addEventListener("click", () => {
    nuiPost("m7mdtool_setClipboard", { text: $("snip_out").value });
    showToast("Copied");
  });

  // Zones
  initZonesUI();

  // Global keybinds
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") nuiPost("m7mdtool_close");
  });

  window.addEventListener("message", (event) => {
    const msg = event.data || {};

    if (msg.action === "open") {
      state.open = true;
      state.items = Array.isArray(msg.items) ? msg.items : [];
      state.moneyTypes = Array.isArray(msg.moneyTypes) ? msg.moneyTypes : [];
      state.jobs = Array.isArray(msg.jobs) ? msg.jobs : [];
      state.gangs = Array.isArray(msg.gangs) ? msg.gangs : [];
      state.config = msg.config || {};

      fillSelect("money_type", state.moneyTypes);

      $("app").classList.remove("hidden");
      setTab(msg.tab || "home");

      // Optional feature toggles
      $("copyStreetBtn").classList.toggle("hidden", !state.config.enableCopyStreetName);
      $("copyPlayerBtn").classList.toggle("hidden", !state.config.enableCopyPlayerInfo);
      $("overlayToggle").closest(".toggle").classList.toggle("hidden", !state.config.enableDebugOverlay);
      $("ev_btn").classList.toggle("hidden", !state.config.enableEventTester);

      return;
    }

    if (msg.action === "close") {
      state.open = false;
      $("app").classList.add("hidden");
      return;
    }

    if (msg.action === "setTab") {
      setTab(msg.tab || "home");
      return;
    }

    if (msg.action === "coords") {
      updateCoords(msg.data);
      if (state.tab === "player") {
        // convenience: fill tp inputs if empty
        if ($("tp_x").value === "" && $("tp_y").value === "" && $("tp_z").value === "") {
          $("tp_x").value = formatNum(msg.data.x);
          $("tp_y").value = formatNum(msg.data.y);
          $("tp_z").value = formatNum(msg.data.z);
          $("tp_h").value = formatNum(msg.data.h);
        }
      }
    }
  });
}

init();

