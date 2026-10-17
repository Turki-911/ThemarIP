// ============================================================
// BANK SMS CONFIGURATION  (admin page: view-sms-config)
// Self-contained module — hooks into the existing Nav / Toast / Modal / Confirm helpers.
// Supports multiple Pattern + Sample Message cards under a single Bank SMS Rule.
// ============================================================
const SmsConfig = {
  _rules: [],
  _patterns: [],
  FIELDS: ['amount', 'type', 'merchant', 'narration', 'reference', 'date', 'balance', 'currency'],
  APP_BANK_CODES: {
    'bank muscat': 'BANK_MUSCAT',
    'national bank of oman': 'NBO',
    'national bank of oman (nbo)': 'NBO',
    'bank dhofar': 'BANK_DHOFAR',
    'oman arab bank': 'OAB',
    'oman arab bank (oab)': 'OAB',
    'sohar international': 'SOHAR_INTL',
    'ahli bank oman': 'AHLI_BANK',
    'ahli bank': 'AHLI_BANK',
    'bank nizwa': 'BANK_NIZWA',
    'alizz islamic bank': 'ALIZZ_ISLAMIC',
  },

  // ── helpers ────────────────────────────────────────────────
  esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  },

  async api(path, opts = {}) {
    const headers = { 'Content-Type': 'application/json', ...(opts.headers || {}) };
    if (state.token) headers['Authorization'] = 'Bearer ' + state.token;
    const res = await fetch(THEMAR_API_BASE + path, { ...opts, headers });
    if (res.status === 401 || res.status === 403) {
      throw new Error('Not authorized. Sign out and sign in again with an administrator account.');
    }
    let body = null;
    try { body = await res.json(); } catch (_) { /* empty body */ }
    if (!res.ok) throw new Error((body && body.message) || ('Request failed (' + res.status + ')'));
    return body;
  },

  // ── page render ────────────────────────────────────────────
  async render() {
    await Promise.all([SmsConfig.loadRules(), SmsConfig.loadLog()]);
  },

  getRulePatterns(r) {
    if (r && Array.isArray(r.patterns) && r.patterns.length > 0) {
      return r.patterns.map(p => ({
        name: p.name || '',
        sampleMessage: p.sampleMessage || '',
        pattern: p.pattern || '',
        fieldMappings: { ...(p.fieldMappings || { amount: 'amount' }) },
        defaultType: p.defaultType || '',
      }));
    }
    if (r && (r.pattern || r.sampleMessage)) {
      return [{
        name: r.bankName || 'Pattern 1',
        sampleMessage: r.sampleMessage || '',
        pattern: r.pattern || '',
        fieldMappings: { ...(r.fieldMappings || { amount: 'amount' }) },
        defaultType: r.defaultType || '',
      }];
    }
    return [{
      name: '',
      sampleMessage: '',
      pattern: '',
      fieldMappings: { amount: 'amount' },
      defaultType: '',
    }];
  },

  async loadRules() {
    const tbody = document.getElementById('tbody-sms-rules');
    if (!tbody) return;
    try {
      SmsConfig._rules = await SmsConfig.api('/admin/sms-rules');
    } catch (e) {
      tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><p class="empty-state-title">${SmsConfig.esc(e.message)}</p></div></td></tr>`;
      return;
    }
    if (SmsConfig._rules.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><p class="empty-state-title">No bank SMS rules yet</p><p style="color:var(--text-muted);font-size:12px;">Add a rule to start detecting transactions from bank SMS.</p></div></td></tr>`;
      return;
    }
    tbody.innerHTML = SmsConfig._rules.map(r => {
      const pats = SmsConfig.getRulePatterns(r);
      const patNames = pats.map((p, i) => p.name || `Pattern ${i + 1}`).join(' • ');
      const ver = r.version && r.version >= 1 ? r.version : 1;
      return `<tr>
        <td>
          <div style="font-weight:600;display:flex;align-items:center;gap:8px;">
            <span>${SmsConfig.esc(r.bankName)}</span>
            <span class="badge" style="background:rgba(124,58,237,0.14);color:#A78BFA;border:1px solid rgba(124,58,237,0.3);font-size:11px;">
              ${pats.length} pattern${pats.length === 1 ? '' : 's'}
            </span>
          </div>
          <div style="font-size:11px;color:var(--text-dim);margin-top:2px;">
            ${r.bankCode ? `<span style="font-family:monospace;color:var(--text-muted);">${SmsConfig.esc(r.bankCode)}</span> — ` : ''}${SmsConfig.esc(patNames)}
          </div>
        </td>
        <td style="font-size:12px;color:var(--text-muted);font-family:monospace;">${SmsConfig.esc(r.senderIds)}</td>
        <td style="text-align:center;color:var(--text-muted);">v${ver}</td>
        <td>${Utils.statusBadge(r.isActive ? 'active' : 'inactive')}</td>
        <td style="font-size:12px;color:var(--text-muted);">${r.updatedAt ? new Date(r.updatedAt).toLocaleString('en-GB') : '--'}${r.updatedBy ? '<br><span style="color:var(--text-dim);">' + SmsConfig.esc(r.updatedBy) + '</span>' : ''}</td>
        <td>
          <div style="display:flex;gap:6px;">
            <button class="btn btn-xs btn-secondary" data-sms-edit="${r.id}" title="Edit"><i data-lucide="pencil" style="width:12px;"></i></button>
            <button class="btn btn-xs btn-ghost" data-sms-toggle="${r.id}" title="${r.isActive ? 'Deactivate' : 'Activate'}" style="color:${r.isActive ? 'var(--accent-amber)' : 'var(--accent-emerald)'}"><i data-lucide="${r.isActive ? 'pause-circle' : 'play-circle'}" style="width:12px;"></i></button>
            <button class="btn btn-xs btn-ghost" data-sms-delete="${r.id}" title="Delete" style="color:var(--accent-rose);"><i data-lucide="trash-2" style="width:12px;"></i></button>
          </div>
        </td></tr>`;
    }).join('');
    refreshIcons();
  },

  async loadLog() {
    const tbody = document.getElementById('tbody-sms-log');
    if (!tbody) return;
    let rows;
    try { rows = await SmsConfig.api('/admin/sms-rules/logs?take=50'); }
    catch (e) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:16px;color:var(--text-muted);">${SmsConfig.esc(e.message)}</td></tr>`;
      return;
    }
    if (!rows.length) {
      tbody.innerHTML = `<tr><td colspan="6" style="text-align:center;padding:16px;color:var(--text-muted);">No SMS processed yet.</td></tr>`;
      return;
    }
    const color = { Saved: 'var(--accent-emerald)', Duplicate: 'var(--accent-amber)', NoRule: 'var(--text-dim)', NoMatch: 'var(--accent-amber)', ValidationFailed: 'var(--accent-rose)', Error: 'var(--accent-rose)' };
    tbody.innerHTML = rows.map((l, idx) => `<tr>
      <td style="font-size:12px;color:var(--text-muted);white-space:nowrap;">${new Date(l.createdAt).toLocaleString('en-GB')}</td>
      <td style="font-family:monospace;font-size:12px;">${SmsConfig.esc(l.sender)}</td>
      <td><span style="font-weight:600;font-size:12px;color:${color[l.status] || 'inherit'};">${SmsConfig.esc(l.status)}</span>${l.ruleVersion ? ' <span style="color:var(--text-dim);font-size:11px;">v' + l.ruleVersion + '</span>' : ''}</td>
      <td style="font-size:12px;color:var(--text-muted);">${SmsConfig.esc(l.details)}</td>
      <td style="font-size:12px;max-width:340px;" class="truncate" title="${SmsConfig.esc(l.rawMessage)}">${SmsConfig.esc(l.rawMessage)}</td>
      <td>
        <div style="display:flex;gap:5px;">
          <button class="btn btn-xs btn-primary" data-sms-reprocess-id="${l.id}" title="Re-process this message against active rules">
            <i data-lucide="rotate-cw" style="width:12px;margin-right:2px;"></i> Re-process
          </button>
          <button class="btn btn-xs btn-secondary" data-sms-test-idx="${idx}" title="Test or edit rule with this SMS message">
            <i data-lucide="flask-conical" style="width:12px;margin-right:2px;"></i> Test
          </button>
        </div>
      </td>
    </tr>`).join('');
    refreshIcons();
    tbody.querySelectorAll('[data-sms-reprocess-id]').forEach(b => {
      b.addEventListener('click', () => SmsConfig.reprocessLogs(b.dataset.smsReprocessId));
    });
    tbody.querySelectorAll('[data-sms-test-idx]').forEach(b => {
      b.addEventListener('click', () => {
        const row = rows[parseInt(b.dataset.smsTestIdx, 10)];
        if (!row) return;
        SmsConfig.openModalForMessage(row.sender, row.rawMessage);
      });
    });
  },

  async reprocessLogs(logId = null) {
    const btn = document.getElementById('btn-reprocess-sms-log');
    if (btn) btn.disabled = true;
    Toast.info(logId ? 'Re-processing message…' : 'Re-processing un-saved SMS logs…');
    try {
      const url = '/admin/sms-rules/logs/reprocess' + (logId ? `?logId=${logId}` : '');
      const res = await SmsConfig.api(url, { method: 'POST' });
      if (res.saved > 0) {
        Toast.success(`Successfully saved ${res.saved} transaction${res.saved > 1 ? 's' : ''} from SMS logs!`);
        if (typeof loadRealTransactions === 'function') loadRealTransactions();
      } else if (res.noMatch > 0) {
        Toast.warning(`${res.noMatch} message${res.noMatch > 1 ? 's' : ''} still had no matching active rule.`);
      } else {
        Toast.info(`Re-process finished: ${res.total} evaluated, ${res.saved} saved.`);
      }
      await SmsConfig.loadLog();
    } catch (e) {
      Toast.error('Re-processing failed: ' + e.message);
    } finally {
      if (btn) btn.disabled = false;
    }
  },

  openModalForMessage(sender, message) {
    const sLower = (sender || '').toLowerCase().trim();
    const existing = SmsConfig._rules.find(r => (r.senderIds || '').toLowerCase().includes(sLower));
    SmsConfig.openModal(existing ? existing.id : null);
    if (message) {
      const firstSample = document.querySelector('[data-pat-field="sampleMessage"][data-pat-idx="0"]');
      if (firstSample) firstSample.value = message;
    }
    if (!existing && sender) {
      SmsConfig._set('sms-form-senders', sender);
      const bankGuess = sender.replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
      SmsConfig._set('sms-form-bank', bankGuess);
      const mappedCode = SmsConfig.APP_BANK_CODES[bankGuess.toLowerCase()];
      if (mappedCode) SmsConfig._set('sms-form-bankcode', mappedCode);
    }
  },

  // ── modal & multi-pattern cards ────────────────────────────
  _val(id) { return document.getElementById(id)?.value ?? ''; },
  _set(id, v) { const el = document.getElementById(id); if (el) el.value = v ?? ''; },

  syncPatternsFromDom() {
    const cards = document.querySelectorAll('#sms-patterns-list .sms-pattern-card');
    if (!cards.length) return;
    SmsConfig._patterns = Array.from(cards).map((card, idx) => {
      const get = (field) => card.querySelector(`[data-pat-field="${field}"]`)?.value ?? '';
      const mappings = {};
      SmsConfig.FIELDS.forEach(f => {
        const v = (card.querySelector(`[data-pat-map="${f}"]`)?.value ?? '').trim();
        if (v) mappings[f] = v;
      });
      return {
        name: get('name').trim(),
        defaultType: get('defaultType'),
        sampleMessage: get('sampleMessage'),
        pattern: get('pattern'),
        fieldMappings: mappings,
      };
    });
  },

  renderPatterns() {
    const container = document.getElementById('sms-patterns-list');
    if (!container) return;
    const total = SmsConfig._patterns.length;

    container.innerHTML = SmsConfig._patterns.map((p, idx) => {
      const map = p.fieldMappings || {};
      return `
        <div class="sms-pattern-card" data-pat-idx="${idx}" style="background:rgba(255,255,255,0.025);border:1px solid rgba(255,255,255,0.09);border-radius:10px;padding:14px;margin-bottom:12px;">
          <div style="display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:10px;">
            <div style="display:flex;align-items:center;gap:8px;">
              <span class="badge" style="background:rgba(124,58,237,0.18);color:#A78BFA;font-weight:700;font-size:11px;">Pattern #${idx + 1}</span>
              <span style="font-size:12px;color:var(--text-muted);font-weight:600;">${SmsConfig.esc(p.name || 'SMS Format')}</span>
            </div>
            ${total > 1 ? `
              <button type="button" class="btn btn-xs btn-ghost" data-pat-remove="${idx}" style="color:var(--accent-rose);" title="Remove this pattern">
                <i data-lucide="trash-2" style="width:12px;margin-right:3px;"></i> Remove
              </button>
            ` : ''}
          </div>

          <div class="form-row">
            <div class="form-group" style="flex:2;">
              <label class="form-label">Pattern Name / Type *</label>
              <input type="text" class="form-control" data-pat-field="name" data-pat-idx="${idx}" value="${SmsConfig.esc(p.name)}" placeholder="e.g. Credit Card Purchase, Debit Card, Transfer Received, ACH Credit">
            </div>
            <div class="form-group" style="flex:1;">
              <label class="form-label">Transaction Direction</label>
              <select class="form-control" data-pat-field="defaultType" data-pat-idx="${idx}">
                <option value="" ${!p.defaultType ? 'selected' : ''}>Auto (use keywords / bank fallback)</option>
                <option value="DEBIT" ${p.defaultType === 'DEBIT' ? 'selected' : ''}>Debit (Expense)</option>
                <option value="CREDIT" ${p.defaultType === 'CREDIT' ? 'selected' : ''}>Credit (Income)</option>
              </select>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">Sample message</label>
            <textarea class="form-control" rows="2" data-pat-field="sampleMessage" data-pat-idx="${idx}" placeholder="Paste a real bank SMS for this pattern (e.g. Card 420460******0292 used for OMR 9.400 at 7202 OMAN OIL MAZOON STRE on 16/10/2026 13:56:51. Available limit OMR 817.560.)">${SmsConfig.esc(p.sampleMessage)}</textarea>
          </div>

          <div class="form-group">
            <label class="form-label">Message pattern (regex with named groups) *</label>
            <textarea class="form-control" rows="3" style="font-family:monospace;font-size:12px;" data-pat-field="pattern" data-pat-idx="${idx}" placeholder="Card\\s+\\S+\\s+used\\s+for\\s+(?<currency>[A-Z]{3})\\s+(?<amount>[\\d,]+(?:\\.\\d+)?)\\s+at\\s+(?<merchant>.+?)\\s+on\\s+(?<date>\\d{2}/\\d{2}/\\d{4}\\s+\\d{2}:\\d{2}:\\d{2})">${SmsConfig.esc(p.pattern)}</textarea>
          </div>

          <div style="margin:10px 0 6px;font-size:11.5px;font-weight:600;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.4px;">Field mappings <span style="font-weight:400;text-transform:none;">— regex group names for this pattern</span></div>
          <div class="form-row">
            <div class="form-group" style="flex:1;"><label class="form-label">Amount *</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="amount" value="${SmsConfig.esc(map.amount ?? 'amount')}" placeholder="amount"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Transaction type</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="type" value="${SmsConfig.esc(map.type ?? '')}" placeholder="type"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Merchant</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="merchant" value="${SmsConfig.esc(map.merchant ?? '')}" placeholder="merchant"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Narration <span style="font-weight:400;color:var(--text-dim);">(opt)</span></label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="narration" value="${SmsConfig.esc(map.narration ?? '')}" placeholder="raw SMS if blank"></div>
          </div>
          <div class="form-row">
            <div class="form-group" style="flex:1;"><label class="form-label">Reference</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="reference" value="${SmsConfig.esc(map.reference ?? '')}" placeholder="ref"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Date</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="date" value="${SmsConfig.esc(map.date ?? '')}" placeholder="date"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Balance</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="balance" value="${SmsConfig.esc(map.balance ?? '')}" placeholder="balance"></div>
            <div class="form-group" style="flex:1;"><label class="form-label">Currency</label><input type="text" class="form-control" style="font-family:monospace;" data-pat-map="currency" value="${SmsConfig.esc(map.currency ?? '')}" placeholder="currency"></div>
          </div>

          <div style="margin-top:8px;display:flex;align-items:center;gap:10px;">
            <button type="button" class="btn btn-secondary btn-sm" data-pat-test="${idx}">
              <i data-lucide="flask-conical"></i> Test Pattern #${idx + 1}
            </button>
            <span style="font-size:11.5px;color:var(--text-dim);">Tests this pattern against its sample message above.</span>
          </div>
          <div id="sms-pat-test-result-${idx}" style="margin-top:8px;"></div>
        </div>
      `;
    }).join('');

    refreshIcons();

    container.querySelectorAll('[data-pat-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        SmsConfig.syncPatternsFromDom();
        const i = parseInt(btn.dataset.patRemove, 10);
        if (SmsConfig._patterns.length <= 1) return;
        SmsConfig._patterns.splice(i, 1);
        SmsConfig.renderPatterns();
      });
    });

    container.querySelectorAll('[data-pat-test]').forEach(btn => {
      btn.addEventListener('click', () => {
        const i = parseInt(btn.dataset.patTest, 10);
        SmsConfig.testPattern(i);
      });
    });
  },

  addPattern() {
    SmsConfig.syncPatternsFromDom();
    SmsConfig._patterns.push({
      name: '',
      defaultType: '',
      sampleMessage: '',
      pattern: '',
      fieldMappings: { amount: 'amount', merchant: 'merchant', date: 'date', balance: 'balance', currency: 'currency' },
    });
    SmsConfig.renderPatterns();
    const cards = document.querySelectorAll('#sms-patterns-list .sms-pattern-card');
    const last = cards[cards.length - 1];
    if (last) last.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  },

  openModal(id) {
    const r = id ? SmsConfig._rules.find(x => x.id === id) : null;
    const ver = r && r.version >= 1 ? r.version : 1;
    document.getElementById('sms-modal-title').textContent = r ? `Edit ${r.bankName} (v${ver})` : 'New Bank SMS Rule (v1)';
    SmsConfig._set('sms-form-id', r?.id || '');
    SmsConfig._set('sms-form-bank', r?.bankName || '');
    SmsConfig._set('sms-form-bankcode', r?.bankCode || '');
    SmsConfig._set('sms-form-active', String(r ? r.isActive : true));
    SmsConfig._set('sms-form-senders', r?.senderIds || '');
    SmsConfig._set('sms-form-debit', r ? r.debitKeywords : 'used,debited,withdrawn,purchase,spent,paid');
    SmsConfig._set('sms-form-credit', r ? r.creditKeywords : 'credited,received,deposit,refund');
    SmsConfig._set('sms-form-deftype', r?.defaultType || 'DEBIT');
    SmsConfig._set('sms-form-currency', r?.defaultCurrency || 'OMR');
    SmsConfig._set('sms-form-datefmt', r?.dateFormats || 'dd/MM/yyyy HH:mm:ss|dd/MM/yyyy HH:mm|dd/MM/yyyy');

    SmsConfig._patterns = SmsConfig.getRulePatterns(r);
    SmsConfig.renderPatterns();
    Modal.open('sms-modal-overlay');
  },

  closeModal() { Modal.close('sms-modal-overlay'); },

  collect() {
    SmsConfig.syncPatternsFromDom();
    const patterns = SmsConfig._patterns.map(p => ({
      name: (p.name || '').trim(),
      defaultType: p.defaultType || '',
      sampleMessage: p.sampleMessage || '',
      pattern: p.pattern || '',
      fieldMappings: p.fieldMappings || { amount: 'amount' },
    }));
    const primary = patterns[0] || { pattern: '', sampleMessage: '', fieldMappings: { amount: 'amount' }, defaultType: '' };
    const bankName = SmsConfig._val('sms-form-bank').trim();
    let bankCode = SmsConfig._val('sms-form-bankcode').trim();
    if (!bankCode && bankName) {
      bankCode = SmsConfig.APP_BANK_CODES[bankName.toLowerCase()] || bankName.toUpperCase().replace(/[^A-Z0-9]+/g, '_');
    }
    return {
      bankName,
      bankCode,
      senderIds: SmsConfig._val('sms-form-senders').trim(),
      pattern: primary.pattern,
      fieldMappings: primary.fieldMappings,
      sampleMessage: primary.sampleMessage,
      patterns,
      debitKeywords: SmsConfig._val('sms-form-debit').trim(),
      creditKeywords: SmsConfig._val('sms-form-credit').trim(),
      defaultType: SmsConfig._val('sms-form-deftype'),
      defaultCurrency: SmsConfig._val('sms-form-currency').trim() || 'OMR',
      dateFormats: SmsConfig._val('sms-form-datefmt').trim(),
      isActive: SmsConfig._val('sms-form-active') === 'true',
    };
  },

  async testPattern(idx) {
    const out = document.getElementById(`sms-pat-test-result-${idx}`);
    if (!out) return;
    const fullRule = SmsConfig.collect();
    const pat = fullRule.patterns[idx];
    if (!pat) return;
    if (!(pat.sampleMessage || '').trim()) {
      Toast.warning(`Enter a sample message in Pattern #${idx + 1} to test.`);
      return;
    }
    if (!(pat.pattern || '').trim()) {
      Toast.warning(`Enter a regex pattern in Pattern #${idx + 1} to test.`);
      return;
    }
    out.innerHTML = '<span style="color:var(--text-muted);font-size:12px;">Testing…</span>';
    try {
      const singleRule = {
        ...fullRule,
        pattern: pat.pattern,
        fieldMappings: pat.fieldMappings,
        sampleMessage: pat.sampleMessage,
        defaultType: pat.defaultType || fullRule.defaultType,
        patterns: [pat],
      };
      const r = await SmsConfig.api('/admin/sms-rules/test', {
        method: 'POST',
        body: JSON.stringify({ rule: singleRule, sampleMessage: pat.sampleMessage }),
      });
      const e = r.extracted;
      const rows = e ? [
        ['Pattern', SmsConfig.esc(pat.name || `#${idx + 1}`)],
        ['Amount', e.amount ? `${e.amount.toFixed(3)} ${SmsConfig.esc(e.currency)}` : '—'],
        ['Transaction type', SmsConfig.esc(e.type || '—')],
        ['Merchant', SmsConfig.esc(e.merchant || '—')],
        ['Narration', SmsConfig.esc(e.narration || '— (defaults to raw SMS)')],
        ['Reference', SmsConfig.esc(e.reference || '—')],
        ['Date', e.date ? new Date(e.date).toLocaleString('en-GB') : '—'],
        ['Balance / Limit', e.balance != null ? e.balance.toFixed(3) : '—'],
      ] : [];
      const errs = (r.errors || []).map(x => `<div style="color:var(--accent-rose);font-size:12px;">• ${SmsConfig.esc(x)}</div>`).join('');
      const status = !r.patternValid ? ['Invalid pattern', 'var(--accent-rose)']
        : (r.matched ? ['Matched ✓', 'var(--accent-emerald)'] : ['No match', 'var(--accent-amber)']);
      out.innerHTML = `<div class="table-container-card" style="padding:12px;">
        <div style="font-weight:600;color:${status[1]};margin-bottom:6px;">${status[0]}</div>${errs}
        ${rows.map(([k, v]) => `<div class="detail-row"><span class="detail-label">${k}</span><span class="detail-value">${v}</span></div>`).join('')}
      </div>`;
    } catch (e) {
      out.innerHTML = `<div style="color:var(--accent-rose);font-size:12px;">${SmsConfig.esc(e.message)}</div>`;
    }
  },

  async save() {
    const id = SmsConfig._val('sms-form-id');
    const rule = SmsConfig.collect();
    if (!rule.bankName) { Toast.error('Bank name is required.'); return; }
    if (!rule.senderIds) { Toast.error('At least one sender ID is required.'); return; }
    if (!rule.patterns.length) { Toast.error('At least one message pattern is required.'); return; }
    for (let i = 0; i < rule.patterns.length; i++) {
      const p = rule.patterns[i];
      const label = p.name ? `"${p.name}"` : `Pattern #${i + 1}`;
      if (!p.pattern.trim()) { Toast.error(`${label}: message pattern is required.`); return; }
      if (!p.fieldMappings || !p.fieldMappings.amount) { Toast.error(`${label}: map the Amount field to a regex group.`); return; }
    }
    try {
      await SmsConfig.api(id ? `/admin/sms-rules/${id}` : '/admin/sms-rules', { method: id ? 'PUT' : 'POST', body: JSON.stringify(rule) });
      SmsConfig.closeModal();
      Toast.success(id ? 'Bank rule updated.' : 'Bank rule created.');
      SmsConfig.loadRules();
    } catch (e) { Toast.error(e.message); }
  },

  async toggle(id) {
    const r = SmsConfig._rules.find(x => x.id === id);
    if (!r) return;
    try {
      await SmsConfig.api(`/admin/sms-rules/${id}/active?value=${!r.isActive}`, { method: 'POST' });
      Toast.success(`${r.bankName} ${r.isActive ? 'deactivated' : 'activated'}.`);
      SmsConfig.loadRules();
    } catch (e) { Toast.error(e.message); }
  },

  async remove(id) {
    const r = SmsConfig._rules.find(x => x.id === id);
    if (!r) return;
    const ok = await Confirm.show('Delete rule', `Delete the ${r.bankName} SMS rule? Messages from its senders will no longer be detected.`, 'Delete');
    if (!ok) return;
    try {
      await SmsConfig.api(`/admin/sms-rules/${id}`, { method: 'DELETE' });
      Toast.success('Rule deleted.');
      SmsConfig.loadRules();
    } catch (e) { Toast.error(e.message); }
  },

  _initialized: false,
  initEvents() {
    if (SmsConfig._initialized) return;
    SmsConfig._initialized = true;

    document.addEventListener('click', (e) => {
      const addRuleBtn = e.target.closest('#btn-add-sms-rule');
      if (addRuleBtn) { e.preventDefault(); SmsConfig.openModal(null); return; }

      const editBtn = e.target.closest('[data-sms-edit]');
      if (editBtn) { e.preventDefault(); SmsConfig.openModal(editBtn.dataset.smsEdit); return; }

      const toggleBtn = e.target.closest('[data-sms-toggle]');
      if (toggleBtn) { e.preventDefault(); SmsConfig.toggle(toggleBtn.dataset.smsToggle); return; }

      const delBtn = e.target.closest('[data-sms-delete]');
      if (delBtn) { e.preventDefault(); SmsConfig.remove(delBtn.dataset.smsDelete); return; }

      const addPatBtn = e.target.closest('#sms-btn-add-pattern');
      if (addPatBtn) { e.preventDefault(); SmsConfig.addPattern(); return; }

      const closeBtn = e.target.closest('#sms-modal-close, #sms-modal-cancel');
      if (closeBtn) { e.preventDefault(); SmsConfig.closeModal(); return; }

      const saveBtn = e.target.closest('#sms-modal-save');
      if (saveBtn) { e.preventDefault(); SmsConfig.save(); return; }

      const refreshLogBtn = e.target.closest('#btn-refresh-sms-log');
      if (refreshLogBtn) { e.preventDefault(); SmsConfig.loadLog(); return; }

      const reprocessLogBtn = e.target.closest('#btn-reprocess-sms-log');
      if (reprocessLogBtn) { e.preventDefault(); SmsConfig.reprocessLogs(); return; }
    });

    const bankInput = document.getElementById('sms-form-bank');
    if (bankInput) {
      bankInput.addEventListener('input', () => {
        const codeEl = document.getElementById('sms-form-bankcode');
        const mapped = SmsConfig.APP_BANK_CODES[bankInput.value.trim().toLowerCase()];
        if (codeEl && mapped) codeEl.value = mapped;
      });
    }
  },
};

// Register page title/subtitle with the existing navigation and bind events.
Nav.viewMeta['view-sms-config'] = {
  title: 'Bank SMS Configuration',
  subtitle: 'Configure how bank transaction SMS are recognised and parsed.',
};
SmsConfig.initEvents();
