// ============================================================
// BANK SMS CONFIGURATION  (admin page: view-sms-config)
// Self-contained module — hooks into the existing Nav / Toast / Modal / Confirm helpers.
// ============================================================
const SmsConfig = {
  _rules: [],
  FIELDS: ['amount', 'type', 'merchant', 'narration', 'reference', 'date', 'balance', 'currency'],

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
    tbody.innerHTML = SmsConfig._rules.map(r => `<tr>
      <td style="font-weight:600;">${SmsConfig.esc(r.bankName)}</td>
      <td style="font-size:12px;color:var(--text-muted);font-family:monospace;">${SmsConfig.esc(r.senderIds)}</td>
      <td style="text-align:center;color:var(--text-muted);">v${r.version}</td>
      <td>${Utils.statusBadge(r.isActive ? 'active' : 'inactive')}</td>
      <td style="font-size:12px;color:var(--text-muted);">${r.updatedAt ? new Date(r.updatedAt).toLocaleString('en-GB') : '--'}${r.updatedBy ? '<br><span style="color:var(--text-dim);">' + SmsConfig.esc(r.updatedBy) + '</span>' : ''}</td>
      <td>
        <div style="display:flex;gap:6px;">
          <button class="btn btn-xs btn-secondary" data-sms-edit="${r.id}" title="Edit"><i data-lucide="pencil" style="width:12px;"></i></button>
          <button class="btn btn-xs btn-ghost" data-sms-toggle="${r.id}" title="${r.isActive ? 'Deactivate' : 'Activate'}" style="color:${r.isActive ? 'var(--accent-amber)' : 'var(--accent-emerald)'}"><i data-lucide="${r.isActive ? 'pause-circle' : 'play-circle'}" style="width:12px;"></i></button>
          <button class="btn btn-xs btn-ghost" data-sms-delete="${r.id}" title="Delete" style="color:var(--accent-rose);"><i data-lucide="trash-2" style="width:12px;"></i></button>
        </div>
      </td></tr>`).join('');
    refreshIcons();
    tbody.querySelectorAll('[data-sms-edit]').forEach(b => b.addEventListener('click', () => SmsConfig.openModal(b.dataset.smsEdit)));
    tbody.querySelectorAll('[data-sms-toggle]').forEach(b => b.addEventListener('click', () => SmsConfig.toggle(b.dataset.smsToggle)));
    tbody.querySelectorAll('[data-sms-delete]').forEach(b => b.addEventListener('click', () => SmsConfig.remove(b.dataset.smsDelete)));
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
        <button class="btn btn-xs btn-secondary" data-sms-test-idx="${idx}" title="Test or edit rule with this SMS message">
          <i data-lucide="flask-conical" style="width:12px;margin-right:3px;"></i> Test
        </button>
      </td>
    </tr>`).join('');
    refreshIcons();
    tbody.querySelectorAll('[data-sms-test-idx]').forEach(b => {
      b.addEventListener('click', () => {
        const row = rows[parseInt(b.dataset.smsTestIdx, 10)];
        if (!row) return;
        SmsConfig.openModalForMessage(row.sender, row.rawMessage);
      });
    });
  },

  openModalForMessage(sender, message) {
    const sLower = (sender || '').toLowerCase().trim();
    const existing = SmsConfig._rules.find(r => (r.senderIds || '').toLowerCase().includes(sLower));
    SmsConfig.openModal(existing ? existing.id : null);
    if (message) {
      document.getElementById('sms-form-sample').value = message;
    }
    if (!existing && sender) {
      document.getElementById('sms-form-senders').value = sender;
      document.getElementById('sms-form-bank').value = sender.replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    }
  },

  // ── modal ──────────────────────────────────────────────────
  _val(id) { return document.getElementById(id).value; },
  _set(id, v) { document.getElementById(id).value = v ?? ''; },

  openModal(id) {
    const r = id ? SmsConfig._rules.find(x => x.id === id) : null;
    document.getElementById('sms-modal-title').textContent = r ? `Edit ${r.bankName} (v${r.version})` : 'New Bank SMS Rule';
    SmsConfig._set('sms-form-id', r?.id || '');
    SmsConfig._set('sms-form-bank', r?.bankName);
    SmsConfig._set('sms-form-bankcode', r?.bankCode);
    SmsConfig._set('sms-form-active', String(r ? r.isActive : true));
    SmsConfig._set('sms-form-senders', r?.senderIds);
    SmsConfig._set('sms-form-sample', r?.sampleMessage);
    SmsConfig._set('sms-form-pattern', r?.pattern);
    SmsConfig.FIELDS.forEach(f => SmsConfig._set('sms-map-' + f, r?.fieldMappings?.[f]));
    SmsConfig._set('sms-form-debit', r ? r.debitKeywords : 'debited,withdrawn,purchase,spent,paid');
    SmsConfig._set('sms-form-credit', r ? r.creditKeywords : 'credited,received,deposit,refund');
    SmsConfig._set('sms-form-deftype', r?.defaultType || '');
    SmsConfig._set('sms-form-currency', r?.defaultCurrency || 'OMR');
    SmsConfig._set('sms-form-datefmt', r?.dateFormats);
    document.getElementById('sms-test-result').innerHTML = '';
    Modal.open('sms-modal-overlay');
  },

  closeModal() { Modal.close('sms-modal-overlay'); },

  collect() {
    const mappings = {};
    SmsConfig.FIELDS.forEach(f => { const v = SmsConfig._val('sms-map-' + f).trim(); if (v) mappings[f] = v; });
    return {
      bankName: SmsConfig._val('sms-form-bank').trim(),
      bankCode: SmsConfig._val('sms-form-bankcode').trim(),
      senderIds: SmsConfig._val('sms-form-senders').trim(),
      pattern: SmsConfig._val('sms-form-pattern'),
      fieldMappings: mappings,
      debitKeywords: SmsConfig._val('sms-form-debit').trim(),
      creditKeywords: SmsConfig._val('sms-form-credit').trim(),
      defaultType: SmsConfig._val('sms-form-deftype'),
      defaultCurrency: SmsConfig._val('sms-form-currency').trim() || 'OMR',
      dateFormats: SmsConfig._val('sms-form-datefmt').trim(),
      sampleMessage: SmsConfig._val('sms-form-sample'),
      isActive: SmsConfig._val('sms-form-active') === 'true',
    };
  },

  async test() {
    const out = document.getElementById('sms-test-result');
    const rule = SmsConfig.collect();
    if (!rule.sampleMessage.trim()) { Toast.warning('Enter a sample message to test.'); return; }
    out.innerHTML = '<span style="color:var(--text-muted);font-size:12px;">Testing…</span>';
    try {
      const r = await SmsConfig.api('/admin/sms-rules/test', { method: 'POST', body: JSON.stringify({ rule, sampleMessage: rule.sampleMessage }) });
      const e = r.extracted;
      const rows = e ? [
        ['Amount', e.amount ? `${e.amount.toFixed(3)} ${SmsConfig.esc(e.currency)}` : '—'],
        ['Transaction type', SmsConfig.esc(e.type || '—')],
        ['Merchant', SmsConfig.esc(e.merchant || '—')],
        ['Narration', SmsConfig.esc(e.narration || '— (defaults to raw SMS)')],
        ['Reference', SmsConfig.esc(e.reference || '—')],
        ['Date', e.date ? new Date(e.date).toLocaleString('en-GB') : '—'],
        ['Balance', e.balance != null ? e.balance.toFixed(3) : '—'],
      ] : [];
      const errs = (r.errors || []).map(x => `<div style="color:var(--accent-rose);font-size:12px;">• ${SmsConfig.esc(x)}</div>`).join('');
      const status = !r.patternValid ? ['Invalid pattern', 'var(--accent-rose)']
        : (r.matched ? ['Matched', 'var(--accent-emerald)'] : ['No match', 'var(--accent-amber)']);
      out.innerHTML = `<div class="table-container-card" style="padding:14px;">
        <div style="font-weight:600;color:${status[1]};margin-bottom:8px;">${status[0]}</div>${errs}
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
    if (!rule.pattern.trim()) { Toast.error('A message pattern is required.'); return; }
    if (!rule.fieldMappings.amount) { Toast.error('Map the Amount field to a regex group.'); return; }
    try {
      await SmsConfig.api(id ? `/admin/sms-rules/${id}` : '/admin/sms-rules', { method: id ? 'PUT' : 'POST', body: JSON.stringify(rule) });
      SmsConfig.closeModal();
      Toast.success(id ? 'Rule updated.' : 'Rule created.');
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

  initEvents() {
    const on = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', fn); };
    on('btn-add-sms-rule', () => SmsConfig.openModal(null));
    on('btn-refresh-sms-log', () => SmsConfig.loadLog());
    on('sms-modal-close', SmsConfig.closeModal);
    on('sms-modal-cancel', SmsConfig.closeModal);
    on('sms-modal-save', SmsConfig.save);
    on('sms-btn-test', SmsConfig.test);
  },
};

// Register page title/subtitle with the existing navigation and bind events.
Nav.viewMeta['view-sms-config'] = {
  title: 'Bank SMS Configuration',
  subtitle: 'Configure how bank transaction SMS are recognised and parsed.',
};
SmsConfig.initEvents();
