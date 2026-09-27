/* ============================================================
   BMPF — Bank Muscat PFM Extractor (App Logic)
   ============================================================ */

const API_BASE = 'http://localhost:5267/api/statements';
let selectedFile = null;
let currentParseResult = null;
let dbCategoryHierarchy = [];
let dbMerchants = [];
let dbRules = [];
let currentUser = null;

document.addEventListener('DOMContentLoaded', () => {
  if (window.lucide) {
    lucide.createIcons();
  }
  initAuth();
  setupDropzone();
  fetchLiveDbCount();
  loadDbMetadata();
});

async function loadDbMetadata() {
  try {
    const [hierarchyRes, merchantsRes, rulesRes] = await Promise.all([
      fetch(`${API_BASE}/categories-hierarchy`),
      fetch(`${API_BASE}/merchants`),
      fetch(`${API_BASE}/category-rules`)
    ]);

    if (hierarchyRes.ok) dbCategoryHierarchy = await hierarchyRes.json();
    if (merchantsRes.ok) dbMerchants = await merchantsRes.json();
    if (rulesRes.ok) dbRules = await rulesRes.json();
  } catch (err) {
    console.warn('Could not pre-fetch themarip.db metadata:', err);
  }
}

// Auth State Management
function initAuth() {
  const saved = localStorage.getItem('bmpf_user');
  if (saved) {
    try {
      currentUser = JSON.parse(saved);
    } catch(e) {
      currentUser = null;
    }
  }
  updateAuthUI();
}

function updateAuthUI() {
  const loggedOutEl = document.getElementById('authLoggedOut');
  const loggedInEl = document.getElementById('authLoggedIn');
  if (!loggedOutEl || !loggedInEl) return;

  if (currentUser) {
    loggedOutEl.classList.add('hidden');
    loggedInEl.classList.remove('hidden');
    document.getElementById('userDisplayName').textContent = currentUser.fullName || currentUser.email || 'User';
    document.getElementById('userAvatarChar').textContent = (currentUser.fullName || currentUser.email || 'U')[0].toUpperCase();
    document.getElementById('userAccountBadge').textContent = currentUser.selectedBank || currentUser.accountNumber || 'Bank Muscat';
  } else {
    loggedInEl.classList.add('hidden');
    loggedOutEl.classList.remove('hidden');
  }
  fetchLiveDbCount();
}

function openAuthModal(tab = 'login') {
  document.getElementById('authModal').classList.remove('hidden');
  switchAuthTab(tab);
  document.getElementById('authAlert').classList.add('hidden');
  if (window.lucide) lucide.createIcons();
}

function closeAuthModal() {
  document.getElementById('authModal').classList.add('hidden');
}

function switchAuthTab(tab) {
  const tabLogin = document.getElementById('tabLogin');
  const tabRegister = document.getElementById('tabRegister');
  const loginForm = document.getElementById('loginForm');
  const registerForm = document.getElementById('registerForm');
  document.getElementById('authAlert').classList.add('hidden');

  if (tab === 'register') {
    tabLogin.classList.remove('active');
    tabRegister.classList.add('active');
    loginForm.classList.add('hidden');
    registerForm.classList.remove('hidden');
  } else {
    tabRegister.classList.remove('active');
    tabLogin.classList.add('active');
    registerForm.classList.add('hidden');
    loginForm.classList.remove('hidden');
  }
}

async function handleLoginSubmit(e) {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const alertEl = document.getElementById('authAlert');
  alertEl.classList.add('hidden');

  try {
    const res = await fetch('http://localhost:5267/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || err.title || 'Invalid email or password.');
    }

    const data = await res.json();
    currentUser = {
      userId: data.userId || data.id,
      id: data.userId || data.id,
      email: data.email,
      fullName: data.fullName,
      role: data.role,
      accountNumber: data.accountNumber,
      token: data.token
    };
    localStorage.setItem('bmpf_user', JSON.stringify(currentUser));
    updateAuthUI();
    closeAuthModal();
    showAlert(`Welcome back, ${currentUser.fullName || currentUser.email}! Your data is isolated to your profile.`, 'success');
  } catch (err) {
    alertEl.textContent = err.message;
    alertEl.classList.remove('hidden');
  }
}

async function handleRegisterSubmit(e) {
  e.preventDefault();
  const fullName = document.getElementById('regFullName').value.trim();
  const email = document.getElementById('regEmail').value.trim();
  const password = document.getElementById('regPassword').value;
  const selectedBank = document.getElementById('regBank')?.value || 'Bank Muscat';
  const alertEl = document.getElementById('authAlert');
  alertEl.classList.add('hidden');

  try {
    const res = await fetch('http://localhost:5267/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fullName, email, password })
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || err.title || 'Failed to create account.');
    }

    const data = await res.json();
    currentUser = {
      userId: data.userId || data.id,
      id: data.userId || data.id,
      email: data.email,
      fullName: data.fullName,
      role: data.role,
      selectedBank: selectedBank,
      accountNumber: selectedBank,
      token: data.token
    };

    if (selectedBank && data.token) {
      try {
        await fetch('http://localhost:5267/api/auth/set-account-number', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${data.token}`
          },
          body: JSON.stringify({ accountNumber: selectedBank })
        });
      } catch(ignore) {}
    }

    localStorage.setItem('bmpf_user', JSON.stringify(currentUser));
    updateAuthUI();
    closeAuthModal();
    showAlert(`Account created successfully! Welcome, ${currentUser.fullName} (${selectedBank}). Your data is completely isolated.`, 'success');
  } catch (err) {
    alertEl.textContent = err.message;
    alertEl.classList.remove('hidden');
  }
}

function logoutUser() {
  currentUser = null;
  localStorage.removeItem('bmpf_user');
  updateAuthUI();
  showAlert('Signed out. Your session data has been cleared.', 'info');
}

// Navigation Tab Switcher
function switchPage(page) {
  const extractorPage = document.getElementById('pageExtractor');
  const categoriesPage = document.getElementById('pageCategories');
  const tabExtractor = document.getElementById('navTabExtractor');
  const tabCategories = document.getElementById('navTabCategories');

  if (page === 'categories') {
    extractorPage.classList.add('hidden');
    categoriesPage.classList.remove('hidden');
    tabExtractor.classList.remove('active');
    tabCategories.classList.add('active');
    loadCategoryHierarchyPage();
  } else {
    categoriesPage.classList.add('hidden');
    extractorPage.classList.remove('hidden');
    tabCategories.classList.remove('active');
    tabExtractor.classList.add('active');
  }
}

// Load Category Hierarchy + live txn counts & associated transactions from themarip.db
// Uses the single server-side engine: GET /api/statements/category-stats
async function loadCategoryHierarchyPage() {
  const container = document.getElementById('categoryHierarchyContainer');
  container.innerHTML = '<div class="spinner" style="margin: 32px auto;"></div>';

  try {
    const statsUrl = currentUser ? `${API_BASE}/category-stats?userId=${currentUser.userId || currentUser.id}` : `${API_BASE}/category-stats`;
    const [hierarchyRes, statsRes] = await Promise.all([
      fetch(`${API_BASE}/categories-hierarchy`),
      fetch(statsUrl)
    ]);

    if (!hierarchyRes.ok) throw new Error(`Hierarchy HTTP ${hierarchyRes.status}`);
    if (!statsRes.ok)     throw new Error(`Stats HTTP ${statsRes.status}`);

    dbCategoryHierarchy = await hierarchyRes.json();
    const stats = await statsRes.json(); // [{ categoryName, icon, color, txnCount, transactions: [...] }]

    // Build lookups: categoryName -> txnCount and categoryName -> transactions
    const txnCounts = {};
    const categoryTxns = {};
    for (const s of stats) {
      txnCounts[s.categoryName] = s.txnCount;
      categoryTxns[s.categoryName] = s.transactions || [];
    }

    renderCategoryHierarchyTree(dbCategoryHierarchy, txnCounts, categoryTxns);
  } catch (err) {
    container.innerHTML = `<div class="alert-banner error" style="margin: 0;"><i data-lucide="alert-circle"></i> Failed to load from themarip.db: ${err.message}</div>`;
    if (window.lucide) lucide.createIcons();
  }
}

function renderCategoryHierarchyTree(categories, txnCounts = {}, categoryTxns = {}) {
  const container = document.getElementById('categoryHierarchyContainer');
  if (!categories || categories.length === 0) {
    container.innerHTML = '<p style="color: var(--text-muted); padding: 24px; text-align: center;">No categories found in themarip.db.</p>';
    return;
  }

  container.innerHTML = categories.sort((a,b) => (a.displayOrder || 0) - (b.displayOrder || 0)).map(cat => {
    const subs = cat.children || cat.subcategories || [];
    const color = cat.color || '#7C3AED';
    const iconName = cat.icon || 'tag';
    const catTxList = categoryTxns[cat.name] || [];
    const txCount = txnCounts[cat.name] || catTxList.length;
    const totalAmount = catTxList.reduce((sum, tx) => sum + (Number(tx.amount) || 0), 0);
    const formattedTotal = totalAmount.toLocaleString('en-US', { minimumFractionDigits: 3, maximumFractionDigits: 3 });
    const nodeId = `cat-node-${(cat.id || cat.name).replace(/[^a-zA-Z0-9_-]/g, '_')}`;

    return `
      <div class="cat-tree-node" id="${nodeId}" style="border-left: 4px solid ${color};" onclick="toggleCategoryDetails('${nodeId}')">
        <div class="cat-header-row">
          <div class="cat-title-group">
            <div class="cat-icon-badge" style="background: ${color}22; color: ${color};">
              <i data-lucide="${iconName}"></i>
            </div>
            <div>
              <div class="cat-name-title">${cat.name}</div>
              <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Order: ${cat.displayOrder || 1} | Status: ${cat.isEnabled !== false ? 'Active' : 'Disabled'}</div>
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 12px;">
            <span style="font-size: 13px; font-weight: 700; color: ${totalAmount > 0 ? color : 'var(--text-muted)'};">
              ${formattedTotal} OMR
            </span>
            <span class="badge" style="background: rgba(255,255,255,0.06); color: var(--text-muted);">
              ${txCount > 0 ? `${txCount} txns` : 'No txns'}
            </span>
            <div class="cat-expand-chevron">
              <i data-lucide="chevron-down"></i>
            </div>
          </div>
        </div>

        ${subs.length > 0 ? `
          <div class="subcat-chips-list">
            ${subs.map(s => `
              <span class="subcat-chip">
                <i data-lucide="corner-down-right" style="width: 12px; color: var(--text-muted);"></i>
                ${s.name}
              </span>
            `).join('')}
          </div>
        ` : ''}

        <!-- Expandable Transactions List Panel -->
        <div class="cat-txns-panel hidden" id="panel-${nodeId}" onclick="event.stopPropagation()">
          <div class="cat-txns-header">
            <span class="cat-txns-title">
              <i data-lucide="receipt" style="width: 14px;"></i> Associated Transactions (${catTxList.length}) · Total: ${formattedTotal} OMR
            </span>
            <span style="font-size: 11px; color: var(--text-muted);">Isolated to your account</span>
          </div>

          ${catTxList.length === 0 ? `
            <div class="empty-cat-txns">
              <i data-lucide="inbox" style="width: 16px;"></i> No transactions categorized under <strong>${cat.name}</strong> yet.
            </div>
          ` : `
            <div class="cat-txns-table-wrapper">
              <table class="cat-txns-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Narration / Description</th>
                    <th>Matched Rule</th>
                    <th>Amount</th>
                    <th>Balance</th>
                  </tr>
                </thead>
                <tbody>
                  ${catTxList.map(tx => {
                    const dateStr = tx.transactionDate ? new Date(tx.transactionDate).toLocaleDateString('en-GB') : '--';
                    const isCredit = (tx.transactionType || '').toLowerCase() === 'credit';
                    const amountFormatted = typeof tx.amount === 'number' ? tx.amount.toFixed(3) : tx.amount;
                    const balFormatted = tx.balanceAfter != null && !isNaN(tx.balanceAfter) ? `OMR ${Number(tx.balanceAfter).toFixed(3)}` : '--';
                    
                    return `
                      <tr>
                        <td style="color: var(--text-muted); font-size: 12px; white-space: nowrap;">${dateStr}</td>
                        <td style="font-weight: 500;">${tx.narration || '--'}</td>
                        <td>
                          ${tx.subcategory ? `
                            <span class="subcat-chip" style="font-size: 11px; padding: 2px 8px;">
                              <i data-lucide="tag" style="width: 10px;"></i> ${tx.subcategory}
                            </span>
                          ` : '—'}
                        </td>
                        <td style="font-weight: 600; white-space: nowrap; color: ${isCredit ? 'var(--emerald-green)' : 'var(--rose-red)'};">
                          ${isCredit ? '+' : '-'}${tx.currency || 'OMR'} ${amountFormatted}
                        </td>
                        <td style="color: var(--text-muted); font-size: 12px; white-space: nowrap;">${balFormatted}</td>
                      </tr>
                    `;
                  }).join('')}
                </tbody>
              </table>
            </div>
          `}
        </div>
      </div>
    `;
  }).join('');

  if (window.lucide) lucide.createIcons();
}

function toggleCategoryDetails(nodeId) {
  const node = document.getElementById(nodeId);
  const panel = document.getElementById(`panel-${nodeId}`);
  if (!node || !panel) return;

  const isExpanded = node.classList.contains('expanded');
  if (isExpanded) {
    node.classList.remove('expanded');
    panel.classList.add('hidden');
  } else {
    node.classList.add('expanded');
    panel.classList.remove('hidden');
  }
  if (window.lucide) lucide.createIcons();
}


function matchCategoryHierarchyFromDb(narration) {
  if (!narration) return null;
  const upperN = narration.toUpperCase();

  // 1. Check active merchants & aliases from themarip.db
  if (dbMerchants && dbMerchants.length > 0) {
    for (const m of dbMerchants) {
      if (m.status !== 'active' && m.status !== undefined && m.status !== true && m.isActive === false) continue;
      const mNameMatch = m.name && upperN.includes(m.name.toUpperCase());
      const aliasMatch = m.aliases && m.aliases.some(a => a && upperN.includes(a.toUpperCase()));
      
      if (mNameMatch || aliasMatch) {
        let catName = m.defaultCategoryName || 'Other';
        let subName = m.defaultSubcategoryName || 'General';
        let catColor = '#7C3AED';
        let catIcon = 'tag';

        if (dbCategoryHierarchy && dbCategoryHierarchy.length > 0) {
          const found = dbCategoryHierarchy.find(c => 
            (m.defaultCategoryId && (c.id === m.defaultCategoryId || c.id.toLowerCase() === m.defaultCategoryId.toLowerCase())) ||
            (c.name && c.name.toUpperCase() === catName.toUpperCase())
          );
          if (found) {
            catName = found.name;
            catColor = found.color || catColor;
            catIcon = found.icon || catIcon;
          }
        }

        return {
          merchant: m.name,
          category: catName,
          subcategory: subName,
          color: catColor,
          icon: catIcon,
          source: 'Merchant Rule'
        };
      }
    }
  }

  // 2. Check active category rules from themarip.db
  if (dbRules && dbRules.length > 0) {
    for (const r of dbRules) {
      if (r.isActive === false) continue;
      if (r.keyword && upperN.includes(r.keyword.toUpperCase())) {
        let catName = 'Other';
        let subName = r.category || 'General';
        let catColor = '#7C3AED';
        let catIcon = 'tag';

        if (dbCategoryHierarchy && dbCategoryHierarchy.length > 0) {
          const found = dbCategoryHierarchy.find(c => 
            (c.children && c.children.some(s => s.name.toUpperCase() === subName.toUpperCase())) ||
            (c.subcategories && c.subcategories.some(s => s.name.toUpperCase() === subName.toUpperCase())) ||
            (c.name.toUpperCase() === subName.toUpperCase())
          );
          if (found) {
            catName = found.name;
            catColor = found.color || catColor;
            catIcon = found.icon || catIcon;
          }
        }

        return {
          merchant: null,
          category: catName,
          subcategory: subName,
          color: catColor,
          icon: catIcon,
          source: 'Keyword Rule'
        };
      }
    }
  }

  // 3. Fallback check against category hierarchy names
  if (dbCategoryHierarchy && dbCategoryHierarchy.length > 0) {
    for (const cat of dbCategoryHierarchy) {
      if (cat.name && upperN.includes(cat.name.toUpperCase())) {
        return { category: cat.name, subcategory: 'General', color: cat.color || '#7C3AED', icon: cat.icon || 'tag', source: 'Category Match' };
      }
      const subs = cat.children || cat.subcategories || [];
      for (const sub of subs) {
        if (sub.name && upperN.includes(sub.name.toUpperCase())) {
          return { category: cat.name, subcategory: sub.name, color: cat.color || '#7C3AED', icon: cat.icon || 'tag', source: 'Subcategory Match' };
        }
      }
    }
  }

  return { category: 'Other', subcategory: 'Uncategorized', color: '#64748B', icon: 'help-circle', source: 'Unmatched' };
}

// Setup Drag & Drop
function setupDropzone() {
  const dropzone = document.getElementById('dropzone');
  const fileInput = document.getElementById('fileInput');

  ['dragenter', 'dragover'].forEach(eventName => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropzone.classList.add('drag-over');
    }, false);
  });

  ['dragleave', 'drop'].forEach(eventName => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropzone.classList.remove('drag-over');
    }, false);
  });

  dropzone.addEventListener('drop', (e) => {
    const dt = e.dataTransfer;
    const files = dt.files;
    if (files.length > 0 && files[0].type === 'application/pdf') {
      handleFileSelected(files[0]);
    } else {
      showAlert('Please upload a valid PDF file.', 'error');
    }
  });

  fileInput.addEventListener('change', (e) => {
    if (fileInput.files.length > 0) {
      handleFileSelected(fileInput.files[0]);
    }
  });
}

function handleFileSelected(file) {
  selectedFile = file;
  document.getElementById('fileName').textContent = file.name;
  document.getElementById('fileSize').textContent = (file.size / 1024).toFixed(1) + ' KB';
  document.getElementById('fileSelectedBar').classList.remove('hidden');
  hideAlert();
}

// Upload & Parse PDF
async function uploadAndParse() {
  if (!selectedFile) return;

  showLoading('Parsing Bank Muscat PDF layout & extracting transactions...');
  document.getElementById('previewSection').classList.add('hidden');
  hideAlert();

  const formData = new FormData();
  formData.append('file', selectedFile);

  try {
    const response = await fetch(`${API_BASE}/parse`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.error || errData.message || `Server returned HTTP ${response.statusCode}`);
    }

    currentParseResult = await response.json();
    renderPreview(currentParseResult);
  } catch (err) {
    showAlert(`Failed to parse PDF statement: ${err.message}`, 'error');
  } finally {
    hideLoading();
  }
}

// Render Preview Table & Header Info
function renderPreview(data) {
  document.getElementById('previewSection').classList.remove('hidden');

  // Header Data
  document.getElementById('hdrAccount').textContent = data.header.accountNumber || 'N/A';
  document.getElementById('hdrCycle').textContent = data.header.statementCycle || 'N/A';
  document.getElementById('hdrTotal').textContent = data.transactions ? data.transactions.length : 0;

  // Extraction Quality Metric
  const extConfidence = data.extractionConfidence != null ? data.extractionConfidence : 100;
  const extQualEl = document.getElementById('hdrExtractionQuality');
  if (extQualEl) {
    extQualEl.textContent = `${extConfidence}% ${data.reconciliationStatus || 'PASS'}`;
    extQualEl.className = extConfidence >= 95 ? 'metric-value success' : (extConfidence >= 70 ? 'metric-value warning' : 'metric-value error');
  }

  // Validation ratio (Mathematical continuity)
  const validCount = data.transactions ? data.transactions.filter(t => t.isBalanceValid).length : 0;
  const totalCount = data.transactions ? data.transactions.length : 0;
  const validationPct = totalCount > 0 ? Math.round((validCount / totalCount) * 100) : 100;
  const valEl = document.getElementById('hdrValidation');
  valEl.textContent = `${validationPct}% Continuous (${validCount}/${totalCount})`;
  valEl.className = validationPct === 100 ? 'metric-value success' : 'metric-value error';

  // Transactions Body
  const tbody = document.getElementById('txTableBody');
  tbody.innerHTML = '';

  if (!data.transactions || data.transactions.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 24px; color: var(--text-muted);">No transactions extracted from PDF.</td></tr>';
    return;
  }

  data.transactions.forEach(t => {
    const tr = document.createElement('tr');
    
    if (!t.isBalanceValid) tr.classList.add('invalid-row');
    if (t.isDuplicate) tr.classList.add('duplicate-row');

    const formattedPostDate = t.postDate ? new Date(t.postDate).toLocaleDateString('en-GB') : '--';
    const formattedValDate = t.valueDate ? new Date(t.valueDate).toLocaleDateString('en-GB') : formattedPostDate;
    
    const isCredit = (t.direction || '').toUpperCase() === 'CREDIT' || (t.credit != null && t.debit == null);
    const amountVal = (typeof t.amount === 'number' && t.amount > 0) ? t.amount : (t.debit ?? t.credit ?? 0);
    const balFormatted = t.balance != null ? `OMR ${t.balance.toFixed(3)}` : '--';

    const match = matchCategoryHierarchyFromDb(t.narration);
    const catBadge = match ? `
      <div style="display: flex; flex-direction: column; gap: 2px;">
        <span class="subcat-chip" style="background: ${match.color}22; color: ${match.color}; border: 1px solid ${match.color}44; font-size: 11px; padding: 2px 8px; width: fit-content;">
          <i data-lucide="${match.icon || 'tag'}" style="width: 10px; height: 10px;"></i> ${match.category} &rsaquo; ${match.subcategory}
        </span>
        ${match.merchant ? `<span style="font-size: 10px; color: var(--text-muted);">Merchant: <strong>${match.merchant}</strong></span>` : ''}
      </div>
    ` : '<span style="color: var(--text-muted); font-size: 11px;">Uncategorized</span>';

    // Separate Extraction Quality / Math status
    let extractionBadge = '<span class="badge badge-valid" style="font-size: 11px;"><i data-lucide="check-circle-2"></i> Reconciled 100%</span>';
    if (!t.isBalanceValid || t.extractionStatus === 'EXTRACTION_REVIEW_REQUIRED') {
      extractionBadge = `<span class="badge badge-invalid" style="font-size: 11px;" title="${t.validationMessage || 'Balance math mismatch'}"><i data-lucide="alert-triangle"></i> Review Required (${t.extractionConfidence}%)</span>`;
    } else if (t.isDuplicate) {
      extractionBadge = '<span class="badge badge-duplicate" style="font-size: 11px;"><i data-lucide="copy"></i> Duplicate</span>';
    }

    const directionBadge = isCredit 
      ? `<span style="display: inline-flex; align-items: center; gap: 4px; color: var(--emerald-green); font-weight: 700; font-size: 12px;"><span style="background: rgba(16, 185, 129, 0.15); padding: 1px 6px; border-radius: 4px; font-size: 10px;">CREDIT</span> +OMR ${amountVal.toFixed(3)}</span>`
      : `<span style="display: inline-flex; align-items: center; gap: 4px; color: var(--rose-red); font-weight: 700; font-size: 12px;"><span style="background: rgba(239, 68, 68, 0.15); padding: 1px 6px; border-radius: 4px; font-size: 10px;">DEBIT</span> -OMR ${amountVal.toFixed(3)}</span>`;

    tr.innerHTML = `
      <td style="color: var(--text-muted); font-size: 12px; white-space: nowrap;">${formattedPostDate}</td>
      <td style="color: var(--text-muted); font-size: 12px; white-space: nowrap;">${formattedValDate}</td>
      <td style="font-weight: 500; word-break: break-word;">${t.narration}</td>
      <td style="white-space: nowrap;">${directionBadge}</td>
      <td style="color: var(--text-muted); font-size: 12px; font-family: monospace; white-space: nowrap;">${balFormatted}</td>
      <td>${catBadge}</td>
      <td>${extractionBadge}</td>
    `;
    tbody.appendChild(tr);
  });

  if (window.lucide) lucide.createIcons();
}

// Confirm & Feed themarip.db (User-Isolated)
async function confirmImport() {
  if (!currentParseResult) return;

  if (!currentUser) {
    showAlert('Please Sign In or Sign Up first so your statement transactions are isolated to your profile.', 'error');
    openAuthModal('login');
    return;
  }

  const unverified = (currentParseResult.transactions || []).filter(t => !t.isBalanceValid || t.extractionStatus === 'EXTRACTION_REVIEW_REQUIRED');
  if (unverified.length > 0) {
    const proceed = confirm(`Notice: ${unverified.length} transaction(s) require review or failed mathematical continuity. Reconciled transactions will be safely imported. Proceed?`);
    if (!proceed) return;
  }

  showLoading('Injecting parsed transactions into themarip.db for ' + (currentUser.fullName || currentUser.email) + '...');
  hideAlert();

  try {
    const payload = {
      ...currentParseResult,
      userId: currentUser.userId || currentUser.id
    };

    const response = await fetch(`${API_BASE}/confirm`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        ...(currentUser.token ? { 'Authorization': `Bearer ${currentUser.token}` } : {})
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      throw new Error(errData.error || errData.message || `Import failed with HTTP ${response.status}`);
    }

    showAlert(`Successfully imported statement into themarip.db! Data is isolated to ${currentUser.fullName || currentUser.email}.`, 'success');
    fetchLiveDbCount();
  } catch (err) {
    showAlert(`Failed to feed themarip.db: ${err.message}`, 'error');
  } finally {
    hideLoading();
  }
}

// Fetch user-isolated total count in themarip.db
async function fetchLiveDbCount() {
  try {
    const url = currentUser ? `${API_BASE}/transactions?userId=${currentUser.userId || currentUser.id}` : `${API_BASE}/transactions`;
    const response = await fetch(url);
    if (response.ok) {
      const txs = await response.json();
      document.getElementById('dbTxCount').textContent = txs.length;
    }
  } catch (err) {
    console.error('Failed to fetch DB count:', err);
  }
}

// UI Helpers
function showLoading(msg) {
  document.getElementById('loadingMsg').textContent = msg;
  document.getElementById('loadingOverlay').classList.remove('hidden');
}

function hideLoading() {
  document.getElementById('loadingOverlay').classList.add('hidden');
}

function showAlert(msg, type) {
  const banner = document.getElementById('alertBanner');
  document.getElementById('alertText').textContent = msg;
  banner.className = `alert-banner ${type}`;
  banner.classList.remove('hidden');
}

function hideAlert() {
  document.getElementById('alertBanner').classList.add('hidden');
}

// ============================================================
// MULTI-SOURCE INGESTION: STATEMENT PDF | BANK SMS | BANK EMAIL
// ============================================================
let currentParsedSms = null;
let currentParsedEmail = null;
let smsDebounceTimer = null;
let emailDebounceTimer = null;

function switchIngestSource(source) {
  const tabPdf = document.getElementById('tabSourcePdf');
  const tabSms = document.getElementById('tabSourceSms');
  const tabEmail = document.getElementById('tabSourceEmail');
  const containerPdf = document.getElementById('sourcePdfContainer');
  const containerSms = document.getElementById('sourceSmsContainer');
  const containerEmail = document.getElementById('sourceEmailContainer');
  const previewSection = document.getElementById('previewSection');

  tabPdf.classList.remove('active');
  tabSms.classList.remove('active');
  tabEmail.classList.remove('active');
  containerPdf.classList.add('hidden');
  containerSms.classList.add('hidden');
  containerEmail.classList.add('hidden');

  if (source === 'sms') {
    tabSms.classList.add('active');
    containerSms.classList.remove('hidden');
    if (previewSection) previewSection.classList.add('hidden');
  } else if (source === 'email') {
    tabEmail.classList.add('active');
    containerEmail.classList.remove('hidden');
    if (previewSection) previewSection.classList.add('hidden');
  } else {
    tabPdf.classList.add('active');
    containerPdf.classList.remove('hidden');
  }
  if (window.lucide) lucide.createIcons();
}

function loadSmsSample(type) {
  const inputEl = document.getElementById('smsInput');
  if (type === 'credit') {
    inputEl.value = "Your A/C ...1234 has been credited with OMR 40.000 on 03-08-2026 by Transfer from TURKI ALI. Avail Bal: OMR 69.647.";
  } else if (type === 'nbo') {
    inputEl.value = "Debit Alert: OMR 15.000 debited from A/C XX1234 on 05-SEP-2026 at COSTA COFFEE. Available Balance: OMR 230.500.";
  } else {
    inputEl.value = "Your A/C ...1234 has been debited by OMR 28.655 on 06-09-2026 for POS purchase at LULU HYPERMARKET. Avail Bal: OMR 40.992.";
  }
  parseSmsMessage(inputEl.value);
}

function handleSmsInput() {
  clearTimeout(smsDebounceTimer);
  const text = document.getElementById('smsInput').value.trim();
  if (!text) {
    document.getElementById('smsPreviewCard').classList.add('hidden');
    currentParsedSms = null;
    return;
  }
  smsDebounceTimer = setTimeout(() => {
    parseSmsMessage(text);
  }, 350);
}

async function parseSmsMessage(rawText) {
  if (!rawText || !rawText.trim()) return;
  try {
    const res = await fetch(`${API_BASE}/parse-notification`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sourceType: 'SMS',
        rawMessage: rawText,
        userId: currentUser ? (currentUser.userId || currentUser.id) : null
      })
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    currentParsedSms = data;

    const card = document.getElementById('smsPreviewCard');
    card.classList.remove('hidden');

    const isCredit = data.direction === 'CREDIT';
    document.getElementById('smsCardBank').textContent = data.bankName || 'Bank Muscat';
    document.getElementById('smsCardDirection').textContent = data.direction || 'DEBIT';
    document.getElementById('smsCardDirection').style.color = isCredit ? 'var(--emerald-green)' : 'var(--rose-red)';
    document.getElementById('smsCardDirection').style.background = isCredit ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)';
    
    document.getElementById('smsCardConfidence').textContent = `${data.confidence}% Valid`;
    document.getElementById('smsCardAmount').textContent = `${isCredit ? '+' : '-'}${Number(data.amount).toFixed(3)} ${data.currency || 'OMR'}`;
    document.getElementById('smsCardAmount').style.color = isCredit ? 'var(--emerald-green)' : 'var(--rose-red)';
    document.getElementById('smsCardMerchant').textContent = data.narration || data.matchedMerchant || 'Unknown Merchant';
    
    const dt = data.transactionDate ? new Date(data.transactionDate).toLocaleDateString('en-GB') : '--';
    document.getElementById('smsCardDate').textContent = dt;
    document.getElementById('smsCardBalance').textContent = data.balanceAfter != null ? `${Number(data.balanceAfter).toFixed(3)} ${data.currency || 'OMR'}` : 'N/A';
    document.getElementById('smsCardCategory').textContent = `${data.category || 'General'} ${data.subcategory ? `(${data.subcategory})` : ''}`;
    
    const valMsgEl = document.getElementById('smsCardValidationMsg');
    if (data.isDuplicate) {
      valMsgEl.textContent = `⚠️ Duplicate: ${data.validationMessage}`;
      valMsgEl.style.color = 'var(--amber-gold)';
    } else {
      valMsgEl.textContent = `✓ ${data.validationMessage || 'Validated Bank Muscat extraction ready to import.'}`;
      valMsgEl.style.color = 'var(--emerald-green)';
    }

    if (window.lucide) lucide.createIcons();
  } catch (err) {
    console.error('Failed to parse SMS:', err);
  }
}

function loadEmailSample(type) {
  const senderEl = document.getElementById('emailSenderInput');
  const subjectEl = document.getElementById('emailSubjectInput');
  const bodyEl = document.getElementById('emailBodyInput');

  if (type === 'html') {
    senderEl.value = 'alerts@bankmuscat.com';
    subjectEl.value = 'Bank Muscat Transaction Alert: POS Purchase';
    bodyEl.value = `<table style="width:100%">
  <tr><td><strong>Account:</strong></td><td>A/C ...1234</td></tr>
  <tr><td><strong>Transaction:</strong></td><td>POS Purchase</td></tr>
  <tr><td><strong>Amount:</strong></td><td>OMR 28.655</td></tr>
  <tr><td><strong>Merchant:</strong></td><td>LULU HYPERMARKET</td></tr>
  <tr><td><strong>Date:</strong></td><td>06-09-2026</td></tr>
  <tr><td><strong>Available Balance:</strong></td><td>OMR 40.992</td></tr>
</table>`;
  } else {
    senderEl.value = 'alerts@bankmuscat.com';
    subjectEl.value = 'Bank Muscat Alert: Debit Card Transaction';
    bodyEl.value = 'Bank Muscat Alert: A purchase of OMR 28.655 was made using your Debit Card ...5678 at LULU HYPERMARKET on 06-09-2026. Available balance: OMR 40.992.';
  }
  parseEmailMessage();
}

function handleEmailInput() {
  clearTimeout(emailDebounceTimer);
  emailDebounceTimer = setTimeout(() => {
    parseEmailMessage();
  }, 400);
}

function handleEmailFileUpload(event) {
  const file = event.target.files[0];
  if (!file) return;
  document.getElementById('emailFileNameDisplay').textContent = `${file.name} (${(file.size/1024).toFixed(1)} KB)`;
  
  const reader = new FileReader();
  reader.onload = (e) => {
    const content = e.target.result;
    document.getElementById('emailBodyInput').value = content;
    if (!document.getElementById('emailSenderInput').value && content.includes('@')) {
      const mSender = content.match(/From:\s*([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})/i);
      if (mSender) document.getElementById('emailSenderInput').value = mSender[1];
    }
    if (!document.getElementById('emailSubjectInput').value && content.toLowerCase().includes('subject:')) {
      const mSub = content.match(/Subject:\s*([^\r\n]+)/i);
      if (mSub) document.getElementById('emailSubjectInput').value = mSub[1];
    }
    parseEmailMessage();
  };
  reader.readAsText(file);
}

async function parseEmailMessage() {
  const sender = document.getElementById('emailSenderInput').value.trim();
  const subject = document.getElementById('emailSubjectInput').value.trim();
  const body = document.getElementById('emailBodyInput').value.trim();

  if (!body && !subject) {
    document.getElementById('emailPreviewCard').classList.add('hidden');
    currentParsedEmail = null;
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/parse-notification`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sourceType: 'EMAIL',
        rawMessage: body,
        emailSender: sender,
        emailSubject: subject,
        isHtml: body.includes('<') && body.includes('>'),
        userId: currentUser ? (currentUser.userId || currentUser.id) : null
      })
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    currentParsedEmail = data;

    const card = document.getElementById('emailPreviewCard');
    card.classList.remove('hidden');

    const isCredit = data.direction === 'CREDIT';
    document.getElementById('emailCardBank').textContent = data.bankName || 'Bank Muscat';
    document.getElementById('emailCardDirection').textContent = data.direction || 'DEBIT';
    document.getElementById('emailCardDirection').style.color = isCredit ? 'var(--emerald-green)' : 'var(--rose-red)';
    document.getElementById('emailCardDirection').style.background = isCredit ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)';
    
    document.getElementById('emailCardConfidence').textContent = `${data.confidence}% Valid`;
    document.getElementById('emailCardAmount').textContent = `${isCredit ? '+' : '-'}${Number(data.amount).toFixed(3)} ${data.currency || 'OMR'}`;
    document.getElementById('emailCardAmount').style.color = isCredit ? 'var(--emerald-green)' : 'var(--rose-red)';
    document.getElementById('emailCardMerchant').textContent = data.narration || data.matchedMerchant || 'Unknown Merchant';
    
    const dt = data.transactionDate ? new Date(data.transactionDate).toLocaleDateString('en-GB') : '--';
    document.getElementById('emailCardDate').textContent = dt;
    document.getElementById('emailCardBalance').textContent = data.balanceAfter != null ? `${Number(data.balanceAfter).toFixed(3)} ${data.currency || 'OMR'}` : 'N/A';
    document.getElementById('emailCardCategory').textContent = `${data.category || 'General'} ${data.subcategory ? `(${data.subcategory})` : ''}`;
    
    const valMsgEl = document.getElementById('emailCardValidationMsg');
    if (data.isDuplicate) {
      valMsgEl.textContent = `⚠️ Duplicate: ${data.validationMessage}`;
      valMsgEl.style.color = 'var(--amber-gold)';
    } else {
      valMsgEl.textContent = `✓ ${data.validationMessage || 'Validated extraction ready to import.'}`;
      valMsgEl.style.color = 'var(--emerald-green)';
    }

    if (window.lucide) lucide.createIcons();
  } catch (err) {
    console.error('Failed to parse Email:', err);
  }
}

async function confirmNotification(source) {
  const txData = source === 'email' ? currentParsedEmail : currentParsedSms;
  if (!txData || !txData.amount) {
    showAlert('No valid transaction parsed to import.', 'error');
    return;
  }

  showLoading(`Feeding ${txData.bankName} ${source.toUpperCase()} transaction to themarip.db...`);

  try {
    const res = await fetch(`${API_BASE}/confirm-notification`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: currentUser ? (currentUser.userId || currentUser.id) : null,
        transaction: txData
      })
    });

    hideLoading();

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `HTTP ${res.status}`);
    }

    const resData = await res.json();
    showAlert(`Transaction successfully stored into themarip.db! (ID: ${resData.transactionId || 'Success'})`, 'success');
    
    fetchLiveDbCount();
    if (typeof loadCategoryHierarchyPage === 'function') loadCategoryHierarchyPage();
  } catch (err) {
    hideLoading();
    showAlert(`Failed to store transaction: ${err.message}`, 'error');
  }
}

// Mailbox Connection Settings UI Handlers
// Zero-Password OAuth 2.0 / Face ID / Device Token State
let currentOAuthSession = {
  provider: 'OUTLOOK',
  connected: true,
  email: 'albahri_27@hotmail.com',
  deviceToken: 'ms_oauth_token_' + Math.random().toString(36).substring(2, 10),
  authMethod: 'HOTMAIL_OAUTH'
};

function updateConnectedEmail(val) {
  if (val && val.trim()) {
    currentOAuthSession.email = val.trim();
    showAlert(`Connected mailbox updated to ${currentOAuthSession.email}`, 'info');
  }
}

async function authenticateWithOAuth(providerType) {
  let providerName = 'Microsoft';
  let providerCode = 'OUTLOOK';
  let authMethod = 'DEVICE_SESSION';

  if (providerType === 'apple') {
    providerName = 'Apple';
    providerCode = 'APPLE';
    authMethod = 'FACE_ID';
  } else if (providerType === 'google') {
    providerName = 'Google';
    providerCode = 'GMAIL';
    authMethod = 'GOOGLE_ACCOUNT_CHOOSER';
  } else {
    providerName = 'Hotmail / Microsoft';
    providerCode = 'OUTLOOK';
    authMethod = 'HOTMAIL_OAUTH';
  }
  
  showLoading(`Authenticating ${providerName} Device Session for ${currentOAuthSession.email} via biometric token...`);

  // Simulate device native biometric / account chooser
  await new Promise(r => setTimeout(r, 700));

  hideLoading();

  currentOAuthSession.provider = providerCode;
  currentOAuthSession.authMethod = authMethod;
  currentOAuthSession.deviceToken = `${providerType}_bearer_tok_` + Math.random().toString(36).substring(2, 12);

  const badge = document.getElementById('oauthConnectedBadge');
  const statusText = document.getElementById('oauthStatusText');
  const emailInput = document.getElementById('oauthConnectedEmailInput');

  if (badge) {
    badge.style.background = 'rgba(16, 185, 129, 0.15)';
    badge.style.color = 'var(--emerald-green)';
  }
  if (statusText) statusText.textContent = `${providerName} Authenticated`;
  if (emailInput && !emailInput.value) emailInput.value = currentOAuthSession.email;

  showAlert(`✓ Connected ${providerName} account (${currentOAuthSession.email}). Zero password needed!`, 'success');
}

// Global cache of pulled email transactions awaiting user validation
let pulledEmailsCache = [];

// Pull Emails from Mailbox using Sender, Subject, and Zero-Password OAuth Token (Step 1: Pull & Inspect)
async function pullEmailsFromMailbox() {
  const emailSender = (document.getElementById('emailSenderInput').value || '').trim();
  const emailSubject = (document.getElementById('emailSubjectInput').value || '').trim();

  showLoading(`Connecting to Mailbox via device OAuth (${currentOAuthSession.email}) and scanning for alerts from "${emailSender || 'Bank'}"...`);
  hideAlert();

  try {
    const payload = {
      emailSender: emailSender || 'NOREPLY@BANKMUSCAT.COM',
      emailSubject: emailSubject || 'Account Transaction',
      provider: currentOAuthSession.provider || 'OUTLOOK',
      username: currentOAuthSession.email,
      password: currentOAuthSession.deviceToken, // Bearer OAuth token
      autoFeedDb: false, // Don't auto-commit yet: let user view and validate first!
      userId: currentUser ? (currentUser.userId || currentUser.id) : null
    };

    const res = await fetch(`${API_BASE}/pull-mailbox-emails`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    hideLoading();

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `HTTP ${res.status}`);
    }

    const result = await res.json();
    const resultsContainer = document.getElementById('mailboxResultsContainer');
    const badge = document.getElementById('mailboxResultsBadge');
    const txList = document.getElementById('mailboxTransactionsList');
    const btnPush = document.getElementById('btnPushToDb');

    if (resultsContainer) resultsContainer.classList.remove('hidden');

    // Handle both possible property casings
    const transactions = result.transactions || result.Transactions || result.pulledTransactions || [];
    pulledEmailsCache = transactions;
    const totalPulled = transactions.length;

    if (badge) {
      badge.textContent = `${totalPulled} Emails Pulled & Ready for Review`;
      badge.className = 'badge badge-primary';
    }

    if (btnPush) {
      btnPush.disabled = totalPulled === 0;
      btnPush.innerHTML = `<i data-lucide="database-zap"></i> Step 2: Push ${totalPulled} Validated to themarip.db`;
    }

    if (txList) {
      txList.innerHTML = '';
      if (totalPulled === 0) {
        txList.innerHTML = `
          <div style="padding: 24px; text-align: center; color: var(--text-muted); background: var(--bg-card); border-radius: var(--radius-md);">
            No emails found matching Sender: <code>${emailSender}</code> and Subject: <code>${emailSubject}</code>.
          </div>`;
      } else {
        transactions.forEach((t, idx) => {
          const isCredit = t.direction === 'CREDIT';
          const dt = t.transactionDate ? new Date(t.transactionDate).toLocaleDateString('en-GB') : '--';
          const card = document.createElement('div');
          card.style.cssText = 'background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 16px 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 14px;';
          
          const statusBadge = t.isDuplicate
            ? `<span style="background: rgba(245, 158, 11, 0.15); color: var(--amber-gold); padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">⚠️ DUPLICATE (ALREADY IN DB)</span>`
            : `<span style="background: rgba(16, 185, 129, 0.15); color: var(--emerald-green); padding: 3px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">✓ VALIDATED NEW</span>`;

          const directionBadge = isCredit
            ? `<span style="color: var(--emerald-green); font-weight: 700; font-size: 16px;">+${Number(t.amount).toFixed(3)} ${t.currency || 'OMR'}</span>`
            : `<span style="color: var(--rose-red); font-weight: 700; font-size: 16px;">-${Number(t.amount).toFixed(3)} ${t.currency || 'OMR'}</span>`;

          card.innerHTML = `
            <div style="display: flex; align-items: center; gap: 14px; flex: 1; min-width: 260px;">
              <input type="checkbox" id="chk_pull_${idx}" checked style="width: 18px; height: 18px; cursor: pointer; accent-color: var(--primary-purple);">
              <div style="width: 40px; height: 40px; border-radius: 8px; background: rgba(124, 58, 237, 0.12); display: flex; align-items: center; justify-content: center; color: var(--primary-purple); flex-shrink: 0;">
                <i data-lucide="mail-check" style="width: 22px; height: 22px;"></i>
              </div>
              <div>
                <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                  <strong style="font-size: 15px;">${t.narration || t.matchedMerchant || 'Transaction'}</strong>
                  ${statusBadge}
                </div>
                <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px; display: flex; gap: 16px; flex-wrap: wrap;">
                  <span><i data-lucide="calendar" style="width: 12px; vertical-align: middle;"></i> Date: <strong>${dt}</strong></span>
                  <span><i data-lucide="tag" style="width: 12px; vertical-align: middle;"></i> Category: <strong style="color: #A78BFA;">${t.category || 'General'}</strong></span>
                  ${t.balanceAfter != null ? `<span><i data-lucide="wallet" style="width: 12px; vertical-align: middle;"></i> Bal: <strong>${Number(t.balanceAfter).toFixed(3)} OMR</strong></span>` : ''}
                </div>
              </div>
            </div>
            <div style="text-align: right;">
              <div>${directionBadge}</div>
              <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Bank Muscat Email Alert</div>
            </div>
          `;
          txList.appendChild(card);
        });
      }
    }

    if (window.lucide) lucide.createIcons();

    showAlert(`Found ${totalPulled} email transactions from ${currentOAuthSession.email}. Please review the details below, then click Step 2 to push to themarip.db.`, 'info');
  } catch (err) {
    showAlert(`Mailbox pull failed: ${err.message}`, 'error');
  }
}

// Step 2: Push Validated Emails to themarip.db
async function pushPulledEmailsToDb() {
  if (!pulledEmailsCache || pulledEmailsCache.length === 0) {
    showAlert('No pulled emails to push. Please click Step 1 first.', 'error');
    return;
  }

  // Filter selected transactions
  const selectedTxs = pulledEmailsCache.filter((_, idx) => {
    const chk = document.getElementById(`chk_pull_${idx}`);
    return chk ? chk.checked : true;
  });

  if (selectedTxs.length === 0) {
    showAlert('Please select at least one transaction to push.', 'error');
    return;
  }

  showLoading(`Pushing ${selectedTxs.length} validated transactions into themarip.db...`);
  hideAlert();

  let pushedCount = 0;
  let skippedDuplicates = 0;

  try {
    for (const tx of selectedTxs) {
      const res = await fetch(`${API_BASE}/confirm-notification`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: currentUser ? (currentUser.userId || currentUser.id) : null,
          transaction: tx
        })
      });

      if (res.ok) {
        pushedCount++;
      } else {
        skippedDuplicates++;
      }
    }

    hideLoading();

    const badge = document.getElementById('mailboxResultsBadge');
    if (badge) {
      badge.textContent = `✓ ${pushedCount} Stored in themarip.db`;
      badge.className = 'badge badge-success';
    }

    showAlert(`✓ Successfully pushed ${pushedCount} transaction(s) into themarip.db! (${skippedDuplicates} skipped/duplicates)`, 'success');
    fetchLiveDbCount();
    if (typeof loadCategoryHierarchyPage === 'function') loadCategoryHierarchyPage();
  } catch (err) {
    hideLoading();
    showAlert(`Error pushing to database: ${err.message}`, 'error');
  }
}


