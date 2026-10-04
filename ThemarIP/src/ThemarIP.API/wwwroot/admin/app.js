// ============================================================
// THEMAR IP — PFM Admin Categorization & Intelligence Portal
// app.js — Complete Frontend Application
// ============================================================

'use strict';

// Dynamic API Base URL for local & production tunnel hosting
const THEMAR_API_BASE = (() => {
  if (typeof window === 'undefined') return 'http://localhost:5267/api';
  if (window.location.pathname.startsWith('/admin')) {
    return window.location.origin + '/api';
  }
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    return 'http://localhost:5267/api';
  }
  return 'https://slideshow-cup-stanford-mileage.trycloudflare.com/api';
})();


// Pre-SEED merchant name lookup (avoids circular reference inside IIFE)
const _MERCHANT_NAMES = {
  'm-lulu':'Lulu Hypermarket','m-carrefour':'Carrefour','m-starbucks':'Starbucks',
  'm-costa':'Costa Coffee','m-talabat':'Talabat','m-shell':'Shell',
  'm-omanoil':'Oman Oil','m-ooredoo':'Ooredoo','m-omantel':'Omantel',
  'm-netflix':'Netflix','m-amazon':'Amazon','m-aster':'Aster Pharmacy',
  'm-majan':'Majan Electricity','m-kfc':'KFC','m-pizzahut':'Pizza Hut',
  'm-bankmatm':'Bank Muscat ATM','m-grand':'Muscat Grand Mall',
};

// ============================================================
// SEED DATA
// ============================================================
const SEED = {

  categories: [
    { id:'cat-food',      name:'Food',             icon:'utensils',       color:'#10B981', order:1, enabled:true },
    { id:'cat-transport', name:'Transport',         icon:'car',            color:'#3B82F6', order:2, enabled:true },
    { id:'cat-shopping',  name:'Shopping',          icon:'shopping-bag',   color:'#8B5CF6', order:3, enabled:true },
    { id:'cat-bills',     name:'Bills & Utilities', icon:'zap',            color:'#F59E0B', order:4, enabled:true },
    { id:'cat-entertain', name:'Entertainment',     icon:'tv',             color:'#EC4899', order:5, enabled:true },
    { id:'cat-health',    name:'Health',            icon:'heart-pulse',    color:'#F43F5E', order:6, enabled:true },
    { id:'cat-travel',    name:'Travel',            icon:'plane',          color:'#06B6D4', order:7, enabled:true },
    { id:'cat-income',    name:'Income',            icon:'trending-up',    color:'#34D399', order:8, enabled:true },
    { id:'cat-transfers', name:'Transfers',         icon:'arrow-left-right', color:'#94A3B8', order:9, enabled:true },
    { id:'cat-other',     name:'Other',             icon:'circle-help',    color:'#64748B', order:10, enabled:true },
  ],

  subcategories: [
    // Food
    { id:'sub-groceries',    name:'Groceries',       categoryId:'cat-food',      order:1, enabled:true },
    { id:'sub-restaurants',  name:'Restaurants',     categoryId:'cat-food',      order:2, enabled:true },
    { id:'sub-coffee',       name:'Coffee',          categoryId:'cat-food',      order:3, enabled:true },
    { id:'sub-fastfood',     name:'Fast Food',       categoryId:'cat-food',      order:4, enabled:true },
    { id:'sub-delivery',     name:'Food Delivery',   categoryId:'cat-food',      order:5, enabled:true },
    // Transport
    { id:'sub-fuel',         name:'Fuel',            categoryId:'cat-transport', order:1, enabled:true },
    { id:'sub-taxi',         name:'Taxi',            categoryId:'cat-transport', order:2, enabled:true },
    { id:'sub-public',       name:'Public Transport',categoryId:'cat-transport', order:3, enabled:true },
    { id:'sub-parking',      name:'Parking',         categoryId:'cat-transport', order:4, enabled:true },
    { id:'sub-carmaint',     name:'Car Maintenance', categoryId:'cat-transport', order:5, enabled:true },
    // Shopping
    { id:'sub-clothing',     name:'Clothing',        categoryId:'cat-shopping',  order:1, enabled:true },
    { id:'sub-electronics',  name:'Electronics',     categoryId:'cat-shopping',  order:2, enabled:true },
    { id:'sub-home',         name:'Home',            categoryId:'cat-shopping',  order:3, enabled:true },
    { id:'sub-personal',     name:'Personal Care',   categoryId:'cat-shopping',  order:4, enabled:true },
    { id:'sub-general-shop', name:'General',         categoryId:'cat-shopping',  order:5, enabled:true },
    // Bills
    { id:'sub-electricity',  name:'Electricity',     categoryId:'cat-bills',     order:1, enabled:true },
    { id:'sub-water',        name:'Water',           categoryId:'cat-bills',     order:2, enabled:true },
    { id:'sub-telecom',      name:'Telecom',         categoryId:'cat-bills',     order:3, enabled:true },
    { id:'sub-internet',     name:'Internet',        categoryId:'cat-bills',     order:4, enabled:true },
    // Entertainment
    { id:'sub-streaming',    name:'Streaming',       categoryId:'cat-entertain', order:1, enabled:true },
    { id:'sub-games',        name:'Games',           categoryId:'cat-entertain', order:2, enabled:true },
    { id:'sub-events',       name:'Events',          categoryId:'cat-entertain', order:3, enabled:true },
    // Health
    { id:'sub-pharmacy',     name:'Pharmacy',        categoryId:'cat-health',    order:1, enabled:true },
    { id:'sub-doctor',       name:'Doctor',          categoryId:'cat-health',    order:2, enabled:true },
    { id:'sub-hospital',     name:'Hospital',        categoryId:'cat-health',    order:3, enabled:true },
    // Travel
    { id:'sub-flights',      name:'Flights',         categoryId:'cat-travel',    order:1, enabled:true },
    { id:'sub-hotels',       name:'Hotels',          categoryId:'cat-travel',    order:2, enabled:true },
    { id:'sub-travelserv',   name:'Travel Services', categoryId:'cat-travel',    order:3, enabled:true },
    // Income
    { id:'sub-salary',       name:'Salary',          categoryId:'cat-income',    order:1, enabled:true },
    { id:'sub-other-income', name:'Other Income',    categoryId:'cat-income',    order:2, enabled:true },
    { id:'sub-refund',       name:'Refund',          categoryId:'cat-income',    order:3, enabled:true },
    // Transfers
    { id:'sub-person',       name:'Person',          categoryId:'cat-transfers', order:1, enabled:true },
    { id:'sub-savings',      name:'Savings',         categoryId:'cat-transfers', order:2, enabled:true },
    { id:'sub-internal',     name:'Internal Transfer', categoryId:'cat-transfers', order:3, enabled:true },
    // Other
    { id:'sub-uncategorized',name:'Uncategorized',   categoryId:'cat-other',     order:1, enabled:true },
    { id:'sub-books',        name:'Books',           categoryId:'cat-other',     order:2, enabled:true },
  ],

  merchants: [
    { id:'m-lulu',      name:'Lulu Hypermarket',  aliases:['LULU','LULU HYPER','LULU HYPERMARKET','LULU AL KHUWAIR','LULU MUTTRAH'], mcc:'5411', defaultCategoryId:'cat-food',      defaultSubcategoryId:'sub-groceries',   defaultConfidence:99, txCount:421, correctionRate:1.2, status:'active' },
    { id:'m-carrefour', name:'Carrefour',          aliases:['CARREFOUR','CARREFOUR MUSCAT','CARREFOUR HYPERMARKET'], mcc:'5411', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-groceries', defaultConfidence:99, txCount:287, correctionRate:0.8, status:'active' },
    { id:'m-starbucks', name:'Starbucks',          aliases:['STARBUCKS','STARBUCKS COFFEE','STARBUCKS AL KHUWAIR','SBUX'], mcc:'5814', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-coffee', defaultConfidence:99, txCount:312, correctionRate:0.3, status:'active' },
    { id:'m-costa',     name:'Costa Coffee',       aliases:['COSTA COFFEE','COSTA','COSTA MUSCAT'], mcc:'5814', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-coffee', defaultConfidence:98, txCount:145, correctionRate:0.5, status:'active' },
    { id:'m-talabat',   name:'Talabat',            aliases:['TALABAT','TALABAT OMAN','TALABAT.COM'], mcc:'5812', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-delivery', defaultConfidence:97, txCount:234, correctionRate:2.1, status:'active' },
    { id:'m-shell',     name:'Shell',              aliases:['SHELL','SHELL PETROL','SHELL RUWI','SHELL AL KHUWAIR'], mcc:'5541', defaultCategoryId:'cat-transport', defaultSubcategoryId:'sub-fuel', defaultConfidence:99, txCount:178, correctionRate:0.2, status:'active' },
    { id:'m-omanoil',   name:'Oman Oil',           aliases:['OMAN OIL','OQ','OMAN OIL COMPANY','OMANOIL'], mcc:'5541', defaultCategoryId:'cat-transport', defaultSubcategoryId:'sub-fuel', defaultConfidence:99, txCount:203, correctionRate:0.4, status:'active' },
    { id:'m-ooredoo',   name:'Ooredoo',            aliases:['OOREDOO','OOREDOO OMAN','OOREDOO RECHARGE'], mcc:'4813', defaultCategoryId:'cat-bills', defaultSubcategoryId:'sub-telecom', defaultConfidence:99, txCount:89, correctionRate:0.1, status:'active' },
    { id:'m-omantel',   name:'Omantel',            aliases:['OMANTEL','OMANTEL BROADBAND','OMANTEL POSTPAID'], mcc:'4813', defaultCategoryId:'cat-bills', defaultSubcategoryId:'sub-internet', defaultConfidence:99, txCount:67, correctionRate:0.0, status:'active' },
    { id:'m-netflix',   name:'Netflix',            aliases:['NETFLIX.COM','NETFLIX','NETFLIX INTL'], mcc:'7995', defaultCategoryId:'cat-entertain', defaultSubcategoryId:'sub-streaming', defaultConfidence:99, txCount:36, correctionRate:0.0, status:'active' },
    { id:'m-amazon',    name:'Amazon',             aliases:['AMAZON','AMAZON.COM','AMAZON PRIME','AMZN MKTP'], mcc:'5999', defaultCategoryId:'cat-shopping', defaultSubcategoryId:'sub-general-shop', defaultConfidence:74, txCount:156, correctionRate:8.3, status:'active' },
    { id:'m-aster',     name:'Aster Pharmacy',     aliases:['ASTER PHARMACY','ASTER','ASTER MUSCAT'], mcc:'5912', defaultCategoryId:'cat-health', defaultSubcategoryId:'sub-pharmacy', defaultConfidence:99, txCount:94, correctionRate:0.5, status:'active' },
    { id:'m-majan',     name:'Majan Electricity',  aliases:['MAJAN ELECTRICITY','MAJAN','MCED'], mcc:'4911', defaultCategoryId:'cat-bills', defaultSubcategoryId:'sub-electricity', defaultConfidence:99, txCount:24, correctionRate:0.0, status:'active' },
    { id:'m-kfc',       name:'KFC',                aliases:['KFC','KENTUCKY FRIED CHICKEN','KFC MUSCAT'], mcc:'5814', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-fastfood', defaultConfidence:98, txCount:112, correctionRate:0.6, status:'active' },
    { id:'m-pizzahut',  name:'Pizza Hut',          aliases:['PIZZA HUT','PIZZAHUT','PIZZA HUT OMAN'], mcc:'5812', defaultCategoryId:'cat-food', defaultSubcategoryId:'sub-fastfood', defaultConfidence:98, txCount:78, correctionRate:0.4, status:'active' },
    { id:'m-bankmatm',  name:'Bank Muscat ATM',    aliases:['BANK MUSCAT','BM ATM','BANKMUSCAT'], mcc:'6011', defaultCategoryId:'cat-transfers', defaultSubcategoryId:'sub-internal', defaultConfidence:95, txCount:45, correctionRate:1.0, status:'active' },
    { id:'m-grand',     name:'Muscat Grand Mall',  aliases:['MUSCAT GRAND MALL','GRAND MALL','MGM MUSCAT'], mcc:'5691', defaultCategoryId:'cat-shopping', defaultSubcategoryId:'sub-clothing', defaultConfidence:82, txCount:63, correctionRate:3.4, status:'active' },
  ],

  rules: [
    { id:'rule-001', name:'Starbucks Coffee', conditions:[{field:'merchant_name',operator:'contains',value:'Starbucks',logic:'AND'}], categoryId:'cat-food', subcategoryId:'sub-coffee', confidence:98, priority:90, status:'active', matchCount:312 },
    { id:'rule-002', name:'Costa Coffee', conditions:[{field:'merchant_name',operator:'contains',value:'Costa',logic:'AND'}], categoryId:'cat-food', subcategoryId:'sub-coffee', confidence:97, priority:88, status:'active', matchCount:145 },
    { id:'rule-003', name:'Shell Fuel', conditions:[{field:'merchant_name',operator:'contains',value:'Shell',logic:'AND'},{field:'type',operator:'equals',value:'debit',logic:'AND'}], categoryId:'cat-transport', subcategoryId:'sub-fuel', confidence:99, priority:95, status:'active', matchCount:178 },
    { id:'rule-004', name:'Oman Oil Fuel', conditions:[{field:'merchant_name',operator:'contains',value:'Oman Oil',logic:'AND'}], categoryId:'cat-transport', subcategoryId:'sub-fuel', confidence:99, priority:94, status:'active', matchCount:203 },
    { id:'rule-005', name:'Netflix Streaming', conditions:[{field:'merchant_name',operator:'contains',value:'Netflix',logic:'AND'}], categoryId:'cat-entertain', subcategoryId:'sub-streaming', confidence:99, priority:96, status:'active', matchCount:36 },
    { id:'rule-006', name:'Ooredoo Telecom', conditions:[{field:'merchant_name',operator:'contains',value:'Ooredoo',logic:'AND'}], categoryId:'cat-bills', subcategoryId:'sub-telecom', confidence:99, priority:93, status:'active', matchCount:89 },
    { id:'rule-007', name:'Omantel Internet', conditions:[{field:'merchant_name',operator:'contains',value:'Omantel',logic:'AND'}], categoryId:'cat-bills', subcategoryId:'sub-internet', confidence:99, priority:92, status:'active', matchCount:67 },
    { id:'rule-008', name:'Talabat Delivery', conditions:[{field:'merchant_name',operator:'contains',value:'Talabat',logic:'AND'}], categoryId:'cat-food', subcategoryId:'sub-delivery', confidence:97, priority:87, status:'active', matchCount:234 },
    { id:'rule-009', name:'Lulu Groceries', conditions:[{field:'merchant_name',operator:'contains',value:'Lulu',logic:'AND'}], categoryId:'cat-food', subcategoryId:'sub-groceries', confidence:99, priority:89, status:'active', matchCount:421 },
    { id:'rule-010', name:'Salary Credit', conditions:[{field:'narration',operator:'contains',value:'SALARY',logic:'AND'},{field:'type',operator:'equals',value:'credit',logic:'AND'}], categoryId:'cat-income', subcategoryId:'sub-salary', confidence:97, priority:100, status:'active', matchCount:24 },
    { id:'rule-011', name:'ATM Withdrawal', conditions:[{field:'narration',operator:'contains',value:'ATM',logic:'AND'},{field:'type',operator:'equals',value:'debit',logic:'AND'}], categoryId:'cat-transfers', subcategoryId:'sub-internal', confidence:90, priority:75, status:'active', matchCount:45 },
    { id:'rule-012', name:'High Value Amazon', conditions:[{field:'merchant_name',operator:'contains',value:'Amazon',logic:'AND'},{field:'amount',operator:'greater_than',value:'50',logic:'AND'}], categoryId:'cat-shopping', subcategoryId:'sub-electronics', confidence:65, priority:60, status:'active', matchCount:23 },
    { id:'rule-013', name:'Majan Electricity', conditions:[{field:'merchant_name',operator:'contains',value:'Majan',logic:'AND'}], categoryId:'cat-bills', subcategoryId:'sub-electricity', confidence:99, priority:91, status:'active', matchCount:24 },
    { id:'rule-014', name:'KFC Fast Food', conditions:[{field:'merchant_name',operator:'contains',value:'KFC',logic:'AND'}], categoryId:'cat-food', subcategoryId:'sub-fastfood', confidence:98, priority:86, status:'active', matchCount:112 },
    { id:'rule-015', name:'Aster Pharmacy', conditions:[{field:'merchant_name',operator:'contains',value:'Aster',logic:'AND'}], categoryId:'cat-health', subcategoryId:'sub-pharmacy', confidence:99, priority:88, status:'active', matchCount:94 },
    { id:'rule-016', name:'Transfer OUT narration', conditions:[{field:'narration',operator:'contains',value:'TRANSFER',logic:'AND'},{field:'type',operator:'equals',value:'debit',logic:'AND'}], categoryId:'cat-transfers', subcategoryId:'sub-person', confidence:80, priority:50, status:'inactive', matchCount:12 },
  ],

  confidenceSettings: {
    weights: { merchantMatch:40, mccMatch:30, narrationMatch:15, historicalMatch:10, amountPattern:5 },
    bands: {
      high:   { min:90, max:100, action:'auto_categorize' },
      medium: { min:70, max:89,  action:'categorize_monitor' },
      low:    { min:0,  max:69,  action:'send_to_review' }
    }
  },

  intelligenceRules: [
    {
      id:'intel-001', name:'High Coffee Spending', type:'high_spending', status:'active',
      params:{ categoryName:'Coffee', threshold:50, currency:'OMR', period:'monthly' },
      insightTemplate:'You spent more than {threshold} {currency} on {categoryName} this month.',
      fireCount:23, lastFired:'2026-09-01',
      icon:'coffee', iconColor:'#F59E0B'
    },
    {
      id:'intel-002', name:'Unusual Transaction Amount', type:'unusual_spending', status:'active',
      params:{ multiplier:2, period:'rolling_30d' },
      insightTemplate:'This transaction is {multiplier}x your average transaction amount — flagged as unusual.',
      fireCount:14, lastFired:'2026-08-30',
      icon:'alert-triangle', iconColor:'#F43F5E'
    },
    {
      id:'intel-003', name:'Low Balance Alert', type:'low_balance', status:'active',
      params:{ threshold:50, currency:'OMR' },
      insightTemplate:'Your available balance has dropped below {threshold} {currency}.',
      fireCount:7, lastFired:'2026-08-25',
      icon:'wallet', iconColor:'#F43F5E'
    },
    {
      id:'intel-004', name:'Monthly Spending Increase', type:'spending_increase', status:'active',
      params:{ categoryName:'Food', increasePercent:20 },
      insightTemplate:'Your {categoryName} spending this month is {increasePercent}% higher than last month.',
      fireCount:11, lastFired:'2026-09-01',
      icon:'trending-up', iconColor:'#F97316'
    },
    {
      id:'intel-005', name:'Recurring Transaction Detected', type:'recurring', status:'active',
      params:{ minOccurrences:3, intervalDays:30, toleranceDays:5, amountVariancePct:5 },
      insightTemplate:'We detected a recurring payment — same merchant, similar amount, ~{intervalDays}-day interval.',
      fireCount:18, lastFired:'2026-08-28',
      icon:'repeat', iconColor:'#3B82F6'
    },
    {
      id:'intel-006', name:'High Food Delivery Spending', type:'high_spending', status:'active',
      params:{ categoryName:'Food Delivery', threshold:80, currency:'OMR', period:'monthly' },
      insightTemplate:'You\'ve spent more than {threshold} {currency} on food delivery this month.',
      fireCount:9, lastFired:'2026-08-29',
      icon:'bike', iconColor:'#F97316'
    },
  ],

  users: [
    { id:'user-001', name:'Ahmad Al-Balushi',  email:'ahmad.albalushi@example.om' },
    { id:'user-002', name:'Fatima Al-Rashdi',  email:'fatima.alrashdi@example.om' },
    { id:'user-003', name:'Khalid Al-Habsi',   email:'khalid.alhabsi@example.om' },
    { id:'user-004', name:'Maryam Al-Zadjali', email:'maryam.alzadjali@example.om' },
    { id:'user-005', name:'Sultan Al-Kindi',   email:'sultan.alkindi@example.om' },
  ],

  corrections: [
    { id:'corr-001', transactionId:'txn-048', userId:'user-001', merchantName:'Amazon', narration:'AMAZON PRIME BOOKS', originalCategoryId:'cat-shopping', originalSubcategoryId:'sub-general-shop', originalConfidence:74, correctedCategoryId:'cat-other', correctedSubcategoryId:'sub-books', date:'2026-08-28', status:'pending' },
    { id:'corr-002', transactionId:'txn-052', userId:'user-002', merchantName:'Amazon', narration:'AMZN MKTP EDUCATION', originalCategoryId:'cat-shopping', originalSubcategoryId:'sub-general-shop', originalConfidence:74, correctedCategoryId:'cat-other', correctedSubcategoryId:'sub-books', date:'2026-08-29', status:'pending' },
    { id:'corr-003', transactionId:'txn-061', userId:'user-003', merchantName:'Muscat Grand Mall', narration:'GRAND MALL CLOTHING', originalCategoryId:'cat-shopping', originalSubcategoryId:'sub-clothing', originalConfidence:82, correctedCategoryId:'cat-shopping', correctedSubcategoryId:'sub-personal', date:'2026-08-30', status:'pending' },
    { id:'corr-004', transactionId:'txn-077', userId:'user-001', merchantName:'Talabat', narration:'TALABAT GROCERY DELIVERY', originalCategoryId:'cat-food', originalSubcategoryId:'sub-delivery', originalConfidence:97, correctedCategoryId:'cat-food', correctedSubcategoryId:'sub-groceries', date:'2026-08-31', status:'pending' },
    { id:'corr-005', transactionId:'txn-082', userId:'user-004', merchantName:'Amazon', narration:'AMAZON KINDLE BOOKS', originalCategoryId:'cat-shopping', originalSubcategoryId:'sub-general-shop', originalConfidence:74, correctedCategoryId:'cat-other', correctedSubcategoryId:'sub-books', date:'2026-09-01', status:'pending' },
    { id:'corr-006', transactionId:'txn-091', userId:'user-002', merchantName:'Carrefour', narration:'CARREFOUR PHARMACY', originalCategoryId:'cat-food', originalSubcategoryId:'sub-groceries', originalConfidence:99, correctedCategoryId:'cat-health', correctedSubcategoryId:'sub-pharmacy', date:'2026-09-01', status:'pending' },
    { id:'corr-007', transactionId:'txn-033', userId:'user-005', merchantName:'Unknown Merchant', narration:'ONLINE PAYMENT GATEWAY', originalCategoryId:'cat-other', originalSubcategoryId:'sub-uncategorized', originalConfidence:0, correctedCategoryId:'cat-bills', correctedSubcategoryId:'sub-internet', date:'2026-08-27', status:'approved' },
    { id:'corr-008', transactionId:'txn-019', userId:'user-003', merchantName:'Pizza Hut', narration:'PIZZA HUT CATERING', originalCategoryId:'cat-food', originalSubcategoryId:'sub-fastfood', originalConfidence:98, correctedCategoryId:'cat-food', correctedSubcategoryId:'sub-restaurants', date:'2026-08-25', status:'rejected' },
  ],

  suggestedRules: [
    { id:'sug-001', merchantName:'Amazon', currentCategoryId:'cat-shopping', currentSubcategoryId:'sub-general-shop', suggestedCategoryId:'cat-other', suggestedSubcategoryId:'sub-books', occurrences:43, suggestedConfidence:92, status:'pending', pattern:'AMAZON.*BOOK|AMZN.*KINDLE|AMAZON.*EDUCATION' },
    { id:'sug-002', merchantName:'Carrefour', currentCategoryId:'cat-food', currentSubcategoryId:'sub-groceries', suggestedCategoryId:'cat-health', suggestedSubcategoryId:'sub-pharmacy', occurrences:18, suggestedConfidence:84, status:'pending', pattern:'CARREFOUR.*PHARMA|CARREFOUR.*HEALTH' },
    { id:'sug-003', merchantName:'Talabat', currentCategoryId:'cat-food', currentSubcategoryId:'sub-delivery', suggestedCategoryId:'cat-food', suggestedSubcategoryId:'sub-groceries', occurrences:29, suggestedConfidence:88, status:'pending', pattern:'TALABAT.*GROCER|TALABAT.*MARKET' },
  ],

  auditLog: [
    { id:'audit-001', admin:'System Administrator', action:'CREATE', entity:'Rule', description:'Created rule: Starbucks Coffee → Food / Coffee', timestamp:'2026-09-01T14:23:11' },
    { id:'audit-002', admin:'System Administrator', action:'UPDATE', entity:'Merchant', description:'Updated Amazon confidence: 80% → 74%', timestamp:'2026-09-01T13:45:02' },
    { id:'audit-003', admin:'System Administrator', action:'APPROVE', entity:'Correction', description:'Approved global rule suggestion: Amazon → Other / Books', timestamp:'2026-09-01T12:10:33' },
    { id:'audit-004', admin:'System Administrator', action:'UPDATE', entity:'ConfidenceSettings', description:'Updated weight: Narration Match 20% → 15%', timestamp:'2026-08-31T16:30:00' },
    { id:'audit-005', admin:'System Administrator', action:'CREATE', entity:'Category', description:'Created subcategory: Books under Other', timestamp:'2026-08-31T11:20:45' },
    { id:'audit-006', admin:'System Administrator', action:'TOGGLE', entity:'Rule', description:'Deactivated rule: Transfer OUT narration', timestamp:'2026-08-30T09:15:20' },
    { id:'audit-007', admin:'System Administrator', action:'UPDATE', entity:'IntelligenceRule', description:'Updated Low Balance Alert threshold: 100 → 50 OMR', timestamp:'2026-08-29T15:00:00' },
    { id:'audit-008', admin:'System Administrator', action:'REJECT', entity:'Correction', description:'Rejected correction for Pizza Hut categorization', timestamp:'2026-08-28T10:05:18' },
  ],

  transactions: [],
};

// ============================================================
// STATE
// ============================================================
const state = {
  token: null,
  user: null,

  categories: JSON.parse(JSON.stringify(SEED.categories)),
  subcategories: JSON.parse(JSON.stringify(SEED.subcategories)),
  merchants: JSON.parse(JSON.stringify(SEED.merchants)),
  rules: JSON.parse(JSON.stringify(SEED.rules)),
  transactions: [],
  corrections: JSON.parse(JSON.stringify(SEED.corrections)),
  suggestedRules: JSON.parse(JSON.stringify(SEED.suggestedRules)),
  intelligenceRules: JSON.parse(JSON.stringify(SEED.intelligenceRules)),
  auditLog: JSON.parse(JSON.stringify(SEED.auditLog)),
  confidenceSettings: JSON.parse(JSON.stringify(SEED.confidenceSettings)),

  // Pagination
  txnPage: 1, txnPageSize: 20,
  txnSearch: '', txnFilterCategory: '', txnFilterSource: '', txnFilterConfidence: '', txnFilterType: '', txnFilterStatus: '',

  rulesPage: 1, rulesPageSize: 15,
  rulesSearch: '', rulesFilterStatus: '',

  merchantsPage: 1, merchantsPageSize: 15,
  merchantsSearch: '', merchantsFilterStatus: '', merchantsFilterCategory: '',

  correctionsPage: 1, correctionsPageSize: 15,
  correctionsSearch: '', correctionsFilterStatus: '',

  charts: {},
  activeView: 'view-dashboard',
  activeCorrectionsTab: 'tab-corrections-queue',
};

// ============================================================
// UTILITY HELPERS
// ============================================================
const Utils = {
  fmt: {
    number: (n) => Number(n).toLocaleString(),
    omr: (n) => `${Number(n).toFixed(3)} OMR`,
    pct: (n) => `${Math.round(n)}%`,
    date: (s) => {
      const d = new Date(s);
      return d.toLocaleDateString('en-GB', {day:'2-digit', month:'short', year:'numeric'});
    },
    datetime: (s) => {
      const d = new Date(s);
      return d.toLocaleString('en-GB', {day:'2-digit', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit'});
    },
  },
  getCategoryName: (id) => {
    if (!id) return '—';
    const cleanId = String(id).toLowerCase();
    return state.categories.find(c => String(c.id).toLowerCase() === cleanId)?.name || '—';
  },
  getSubcategoryName: (id) => {
    if (!id) return '—';
    const cleanId = String(id).toLowerCase();
    return state.subcategories.find(s => String(s.id).toLowerCase() === cleanId)?.name || '—';
  },
  getSubcatsForCategory: (catId) => {
    if (!catId) return [];
    const cleanCatId = String(catId).toLowerCase();
    return state.subcategories.filter(s => String(s.categoryId).toLowerCase() === cleanCatId);
  },
  confidenceBadge: (pct) => {
    if (pct >= state.confidenceSettings.bands.high.min) return `<span class="badge badge-high">${pct}%</span>`;
    if (pct >= state.confidenceSettings.bands.medium.min) return `<span class="badge badge-medium">${pct}%</span>`;
    if (pct === 0) return `<span class="badge badge-inactive">—</span>`;
    return `<span class="badge badge-low">${pct}%</span>`;
  },
  sourceBadge: (src) => {
    const labels = {
      MERCHANT_MAPPING:'Merchant Mapping', MCC:'MCC', RULE:'Rule',
      NARRATION:'Narration', HISTORICAL:'Historical', USER_RULE:'User Rule',
      MANUAL:'Manual', UNCATEGORIZED:'Uncategorized'
    };
    const cls = {
      MERCHANT_MAPPING:'source-merchant', MCC:'source-mcc', RULE:'source-rule',
      NARRATION:'source-narration', HISTORICAL:'source-historical', USER_RULE:'source-user-rule',
      MANUAL:'source-manual', UNCATEGORIZED:'source-uncategorized'
    };
    return `<span class="source-badge ${cls[src]||''}">${labels[src]||src}</span>`;
  },
  statusBadge: (status) => {
    const map = {
      categorized:   '<span class="badge badge-active">Categorized</span>',
      uncategorized: '<span class="badge badge-inactive">Uncategorized</span>',
      user_corrected:'<span class="badge badge-pending">User Corrected</span>',
      pending:       '<span class="badge badge-pending">Pending</span>',
      approved:      '<span class="badge badge-approved">Approved</span>',
      rejected:      '<span class="badge badge-inactive">Rejected</span>',
      active:        '<span class="badge badge-active">Active</span>',
      inactive:      '<span class="badge badge-inactive">Inactive</span>',
    };
    return map[status] || `<span class="badge">${status}</span>`;
  },
  priorityBadge: (p) => {
    let cls = p >= 90 ? 'priority-high' : p >= 70 ? 'priority-med' : p >= 50 ? 'priority-low' : 'priority-xlow';
    return `<span class="priority-badge ${cls}">${p}</span>`;
  },
  paginate: (arr, page, size) => arr.slice((page-1)*size, page*size),
  totalPages: (arr, size) => Math.max(1, Math.ceil(arr.length/size)),
};

// ============================================================
// TOAST
// ============================================================
const Toast = {
  show(message, type='info', duration=3500) {
    const container = document.getElementById('toast-container');
    const id = 'toast-' + Date.now();
    const icons = { success:'check-circle', error:'x-circle', warning:'alert-triangle', info:'info' };
    const el = document.createElement('div');
    el.id = id;
    el.className = `toast toast-${type}`;
    el.innerHTML = `<i data-lucide="${icons[type]||'info'}" class="toast-icon"></i><span class="toast-message">${message}</span><button class="toast-close" onclick="document.getElementById('${id}').remove()"><i data-lucide="x"></i></button>`;
    container.appendChild(el);
    refreshIcons();
    setTimeout(()=>{ el.style.opacity='0'; el.style.transform='translateX(100%)'; setTimeout(()=>el.remove(),300); }, duration);
  },
  success: (m)=>Toast.show(m,'success'),
  error:   (m)=>Toast.show(m,'error'),
  warning: (m)=>Toast.show(m,'warning'),
  info:    (m)=>Toast.show(m,'info'),
};

// ============================================================
// AUDIT LOG
// ============================================================
const AuditLog = {
  record(action, entity, description) {
    const entry = {
      id: 'audit-' + Date.now(),
      admin: 'System Administrator',
      action, entity, description,
      timestamp: new Date().toISOString(),
    };
    state.auditLog.unshift(entry);
    AuditLog.render();
  },
  render() {
    const container = document.getElementById('audit-log-list');
    if (!container) return;
    const items = state.auditLog.slice(0, 50);
    if (items.length === 0) {
      container.innerHTML = '<div class="empty-state" style="padding:30px 0;"><p class="empty-state-subtitle">No audit entries yet.</p></div>';
      return;
    }
    const actionColors = { CREATE:'#10B981', UPDATE:'#3B82F6', DELETE:'#F43F5E', APPROVE:'#8B5CF6', REJECT:'#F59E0B', TOGGLE:'#06B6D4' };
    container.innerHTML = items.map(e=>`
      <div class="audit-log-item">
        <div class="audit-dot" style="background:${actionColors[e.action]||'#94A3B8'};"></div>
        <div style="flex:1;min-width:0;">
          <div class="audit-description">${e.description}</div>
          <div class="audit-meta"><span class="audit-entity">${e.entity}</span><span class="audit-time">${Utils.fmt.datetime(e.timestamp)}</span></div>
        </div>
      </div>`).join('');
  }
};

// ============================================================
// CONFIRM DIALOG
// ============================================================
const Confirm = {
  _resolve: null,
  show(title, message, okLabel='Confirm', dangerous=true) {
    return new Promise(resolve => {
      Confirm._resolve = resolve;
      document.getElementById('confirm-title').textContent = title;
      document.getElementById('confirm-message').textContent = message;
      const okBtn = document.getElementById('confirm-ok');
      okBtn.textContent = okLabel;
      okBtn.className = dangerous ? 'btn btn-danger' : 'btn btn-primary';
      document.getElementById('confirm-overlay').classList.remove('hidden');
    });
  },
  close(result) {
    document.getElementById('confirm-overlay').classList.add('hidden');
    if (Confirm._resolve) { Confirm._resolve(result); Confirm._resolve = null; }
  }
};

// ============================================================
// DRAWER
// ============================================================
const Drawer = {
  open(drawerId) {
    document.getElementById('drawer-overlay').classList.remove('hidden');
    const drawer = document.getElementById(drawerId);
    if (drawer) { drawer.classList.add('open'); }
    refreshIcons();
  },
  close(drawerId) {
    document.getElementById('drawer-overlay').classList.add('hidden');
    const drawer = document.getElementById(drawerId);
    if (drawer) drawer.classList.remove('open');
  },
  closeAll() {
    document.getElementById('drawer-overlay').classList.add('hidden');
    document.querySelectorAll('.drawer').forEach(d=>d.classList.remove('open'));
  }
};

// ============================================================
// MODAL
// ============================================================
const Modal = {
  open(id)  { document.getElementById(id).classList.remove('hidden'); refreshIcons(); },
  close(id) { document.getElementById(id).classList.add('hidden'); },
};

// ============================================================
// LUCIDE ICON REFRESH
// ============================================================
function refreshIcons() {
  if (window.lucide) window.lucide.createIcons();
}

// ============================================================
// AUTH
// ============================================================
const Auth = {
  CREDENTIALS: { email:'admin@themar.ip', password:'AdminPassword123!' },
  _pollInterval: null,

  init() {
    document.getElementById('login-form').addEventListener('submit', Auth.handleLogin);
    document.getElementById('btn-logout').addEventListener('click', Auth.handleLogout);

    // ALWAYS enforce login on entry — clear any previously cached session
    state.token = null;
    localStorage.removeItem('themarip_pfm_token');
    sessionStorage.removeItem('themarip_pfm_token');

    // Show login overlay and ensure app container is hidden
    document.getElementById('app-container').classList.add('hidden');
    document.getElementById('login-overlay').classList.remove('hidden');

    const emailInput = document.getElementById('admin-email');
    const passInput = document.getElementById('admin-password');
    if (emailInput) emailInput.value = '';
    if (passInput) passInput.value = '';

    refreshIcons();
  },

  async handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('admin-email').value.trim();
    const password = document.getElementById('admin-password').value;
    const errorBanner = document.getElementById('login-error');
    const errorText = document.getElementById('login-error-text');
    const submitBtn = document.getElementById('btn-login');

    if (!email || !password) {
      errorText.textContent = 'Please enter both administrator email and password.';
      errorBanner.classList.remove('hidden');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span>Verifying credentials...</span>';

    try {
      let authorized = false;
      let token = null;

      // 1. Verify against real .NET backend Web API
      try {
        const res = await fetch(THEMAR_API_BASE + '/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password })
        });
        if (res.ok) {
          const data = await res.json();
          token = data.token;
          authorized = true;
        }
      } catch (apiErr) {
        console.warn('API login check fallback:', apiErr);
      }

      // 2. Also accept Master Administrator credentials
      if (!authorized && email === Auth.CREDENTIALS.email && password === Auth.CREDENTIALS.password) {
        token = 'pfm-admin-token-' + Date.now();
        authorized = true;
      }

      if (authorized && token) {
        state.token = token;
        sessionStorage.setItem('themarip_pfm_token', token);
        errorBanner.classList.add('hidden');
        await Auth.showApp();
      } else {
        errorText.textContent = 'Access Denied: Invalid administrator credentials.';
        errorBanner.classList.remove('hidden');
        refreshIcons();
      }
    } finally {
      submitBtn.disabled = false;
      submitBtn.innerHTML = '<span>Authenticate &amp; Access</span><i data-lucide="arrow-right"></i>';
      refreshIcons();
    }
  },

  handleLogout() {
    if (Auth._pollInterval) {
      clearInterval(Auth._pollInterval);
      Auth._pollInterval = null;
    }
    state.token = null;
    localStorage.removeItem('themarip_pfm_token');
    sessionStorage.removeItem('themarip_pfm_token');
    document.getElementById('app-container').classList.add('hidden');
    document.getElementById('login-overlay').classList.remove('hidden');

    const emailInput = document.getElementById('admin-email');
    const passInput = document.getElementById('admin-password');
    if (emailInput) emailInput.value = '';
    if (passInput) passInput.value = '';

    // Destroy charts
    Object.values(state.charts).forEach(c => { if(c) c.destroy(); });
    state.charts = {};
    refreshIcons();
  },

  async showApp() {
    document.getElementById('login-overlay').classList.add('hidden');
    document.getElementById('app-container').classList.remove('hidden');
    App.init();
    refreshIcons();

    // Load CategoryRules and Merchants from themarip.db
    await loadCategoryRulesFromDb();
    await loadMerchantsFromDb();
    loadRealTransactions();
    if (!Auth._pollInterval) {
      Auth._pollInterval = setInterval(loadRealTransactions, 5000);
    }
  }
};

// ============================================================
// DATA LOADING
// ============================================================
// Smart Narration Categorization Engine for Oman Merchants
// ============================================================
// SINGLE CATEGORIZATION ENGINE — driven by themarip.db CategoryRules
// Fetched once on load; applied to every transaction in loadRealTransactions()
// ============================================================
let _dbCategoryRules = [];   // live from themarip.db CategoryRules table

async function loadCategoryRulesFromDb() {
  try {
    const [rulesRes, catRes] = await Promise.all([
      fetch(THEMAR_API_BASE + '/statements/category-rules'),
      fetch(THEMAR_API_BASE + '/statements/categories-hierarchy')
    ]);

    if (rulesRes.ok) {
      _dbCategoryRules = await rulesRes.json();
      console.log(`[Engine] Loaded ${_dbCategoryRules.length} CategoryRules from themarip.db`);
    }

    if (catRes.ok) {
      const dbCats = await catRes.json();
      if (Array.isArray(dbCats) && dbCats.length > 0) {
        state.categories = [];
        state.subcategories = [];
        dbCats.forEach(c => {
          state.categories.push({
            id: c.id || c.Id,
            name: c.name || c.Name,
            icon: c.icon || c.Icon || 'tag',
            color: c.color || c.Color || '#7C3AED',
            order: c.displayOrder || c.DisplayOrder || 1,
            enabled: c.isEnabled !== false
          });
          if (c.subcategories && Array.isArray(c.subcategories)) {
            c.subcategories.forEach(s => {
              state.subcategories.push({
                id: s.id || s.Id,
                categoryId: c.id || c.Id,
                name: s.name || s.Name,
                order: s.displayOrder || s.DisplayOrder || 1,
                enabled: s.isEnabled !== false
              });
            });
          }
        });
        console.log(`[Engine] Loaded ${state.categories.length} categories & ${state.subcategories.length} subcategories from themarip.db`);
      }
    }
  } catch (e) {
    console.error('[Engine] Failed to load CategoryRules/Hierarchy:', e);
  }
}

async function loadMerchantsFromDb() {
  try {
    const res = await fetch(THEMAR_API_BASE + '/statements/merchants');
    if (res.ok) {
      const dbMerchants = await res.json();
      if (Array.isArray(dbMerchants) && dbMerchants.length > 0) {
        state.merchants = dbMerchants.map(m => ({
          id: m.id,
          name: m.name,
          aliases: m.aliases || [],
          mcc: m.mcc || '',
          defaultCategoryId: m.defaultCategoryId || '',
          defaultCategoryName: m.defaultCategoryName || '',
          defaultSubcategoryId: m.defaultSubcategoryId || '',
          defaultSubcategoryName: m.defaultSubcategoryName || '',
          defaultConfidence: m.defaultConfidence || 90,
          txCount: m.txCount || 0,
          correctionRate: m.correctionRate || 0.0,
          status: m.status || 'active'
        }));
        console.log(`[Engine] Loaded ${state.merchants.length} merchants from themarip.db`);
        if (typeof Merchants !== 'undefined' && Merchants.render) {
          Merchants.render();
        }
        if (typeof Nav !== 'undefined' && Nav.updateBadges) {
          Nav.updateBadges();
        }
      }
    }
  } catch (e) {
    console.error('[Engine] Failed to load merchants from themarip.db:', e);
  }
}

// Maps a DB rule.Category value (subcategory-level name e.g. "Fuel")
// to the Admin portal's cat-* / sub-* IDs
const _ruleCatMap = {
  // Food
  'Groceries':        { categoryId:'cat-food',      subcategoryId:'sub-groceries'    },
  'Coffee':           { categoryId:'cat-food',      subcategoryId:'sub-coffee'       },
  'Food Delivery':    { categoryId:'cat-food',      subcategoryId:'sub-delivery'     },
  'Fast Food':        { categoryId:'cat-food',      subcategoryId:'sub-fastfood'     },
  'Restaurants':      { categoryId:'cat-food',      subcategoryId:'sub-restaurants'  },
  // Transport
  'Fuel':             { categoryId:'cat-transport',  subcategoryId:'sub-fuel'         },
  'Parking':          { categoryId:'cat-transport',  subcategoryId:'sub-parking'      },
  'Public Transit':   { categoryId:'cat-transport',  subcategoryId:'sub-public'       },
  'Taxi & Ride':      { categoryId:'cat-transport',  subcategoryId:'sub-taxi'         },
  // Bills & Utilities
  'Telecom':          { categoryId:'cat-bills',      subcategoryId:'sub-telecom'      },
  'Mobile':           { categoryId:'cat-bills',      subcategoryId:'sub-telecom'      },
  'Subscriptions':    { categoryId:'cat-bills',      subcategoryId:'sub-streaming'    },
  'Electricity':      { categoryId:'cat-bills',      subcategoryId:'sub-electricity'  },
  'Internet':         { categoryId:'cat-bills',      subcategoryId:'sub-internet'     },
  'Water':            { categoryId:'cat-bills',      subcategoryId:'sub-water'        },
  // Transfers
  'Bank Transfer':    { categoryId:'cat-transfers',  subcategoryId:'sub-internal'     },
  'Cash Withdrawal':  { categoryId:'cat-transfers',  subcategoryId:'sub-person'       },
  // Shopping
  'Digital Services': { categoryId:'cat-shopping',   subcategoryId:'sub-general-shop' },
  // Income
  'Income':           { categoryId:'cat-income',     subcategoryId:'sub-other-income' },
  'Salary':           { categoryId:'cat-income',     subcategoryId:'sub-salary'       },
  // Entertainment
  'Streaming':        { categoryId:'cat-entertain',  subcategoryId:'sub-streaming'    },
};

function categorizeNarration(narration) {
  const n = (narration || '').toUpperCase();

  // 1. Check live Merchants and Aliases from themarip.db
  if (Array.isArray(state.merchants)) {
    for (const m of state.merchants) {
      if (m.status !== 'active') continue;
      // Match merchant name or any of its aliases
      const matchesName = m.name && n.includes(m.name.toUpperCase());
      const matchesAlias = Array.isArray(m.aliases) && m.aliases.some(a => a && n.includes(a.toUpperCase()));

      if (matchesName || matchesAlias) {
        const catId = m.defaultCategoryId || 'cat-other';
        const subId = m.defaultSubcategoryId || '';
        const conf = m.defaultConfidence || 95;
        return {
          merchantName:  m.name,
          m:             m.id,
          categoryId:    catId,
          cat:           catId,
          subcategoryId: subId,
          sub:           subId,
          confidence:    conf,
          conf:          conf,
          status:        'categorized',
          source:        'MERCHANT_MAPPING',
          src:           'MERCHANT_MAPPING',
          scores: { merchantMatch:45, mccMatch:25, narrationMatch:15, historicalMatch:10, amountPattern:0 }
        };
      }
    }
  }

  // 2. Use live CategoryRules from themarip.db (sorted by Priority desc)
  const sorted = [..._dbCategoryRules].sort((a, b) => (b.priority || 0) - (a.priority || 0));
  for (const rule of sorted) {
    if (!rule.isActive) continue;
    if (rule.keyword && n.includes(rule.keyword.toUpperCase())) {
      const ids = _ruleCatMap[rule.category] || { categoryId: 'cat-other', subcategoryId: '' };
      return {
        merchantName:    rule.keyword,
        m:               `m-${rule.keyword.toLowerCase().replace(/\s+/g, '-')}`,
        categoryId:      ids.categoryId,
        cat:             ids.categoryId,
        subcategoryId:   ids.subcategoryId,
        sub:             ids.subcategoryId,
        confidence:      90,
        conf:            90,
        status:          'categorized',
        source:          'DB_RULE',
        src:             'DB_RULE',
        scores: { merchantMatch:35, mccMatch:25, narrationMatch:20, historicalMatch:10, amountPattern:0 }
      };
    }
  }

  // Uncategorized fallback
  return {
    merchantName:'Other', m:'', categoryId:'cat-other', cat:'cat-other',
    subcategoryId:'sub-uncategorized', sub:'sub-uncategorized',
    confidence:30, conf:30, status:'uncategorized', source:'DB_RULE', src:'DB_RULE',
    scores:{ merchantMatch:5, mccMatch:5, narrationMatch:10, historicalMatch:5, amountPattern:5 }
  };
}

async function loadRealTransactions() {
  try {
    const res = await fetch(THEMAR_API_BASE + '/statements/transactions');
    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data)) {
        state.transactions = data.map((t, idx) => {
          const narrationText = t.narration || t.Narration || 'Unspecified Transaction';
          const amountValue   = Math.abs(t.amount !== undefined ? t.amount : (t.Amount !== undefined ? t.Amount : 0));
          const balanceValue  = t.balanceAfter !== undefined ? t.balanceAfter : (t.balance !== undefined ? t.balance : (t.BalanceAfter !== undefined ? t.BalanceAfter : (t.Balance !== undefined ? t.Balance : 0)));
          const txType        = (t.transactionType === 0 || t.TransactionType === 0) ? 'debit' : 'credit';
          const txDate        = (t.transactionDate || t.TransactionDate) ? (t.transactionDate || t.TransactionDate).split('T')[0] : '2026-09-01';

          const catInfo = categorizeNarration(narrationText);

          return {
            id: t.id || t.Id || `txn-live-${idx}`,
            merchantName: catInfo.merchantName,
            narration: narrationText,
            amount: amountValue,
            balanceAfter: balanceValue,
            type: txType,
            categoryId: catInfo.categoryId,
            subcategoryId: catInfo.subcategoryId,
            confidence: catInfo.confidence,
            source: catInfo.source,
            status: catInfo.status,
            date: txDate,
            scores: catInfo.scores,
            n: narrationText, amt: amountValue,
            cat: catInfo.cat, sub: catInfo.sub, conf: catInfo.conf, src: catInfo.src, m: catInfo.m
          };
        });

        Dashboard.render();
        Transactions.render();
        Categories.render();
        Nav.updateBadges();
      }
    }
  } catch (err) {
    console.error('Failed to load live transactions:', err);
  }
}


// ============================================================
// NAVIGATION
// ============================================================
const Nav = {
  viewMeta: {
    'view-dashboard':    { title:'Dashboard',             subtitle:'PFM Categorization Engine overview and key metrics.' },
    'view-transactions': { title:'Transactions',          subtitle:'Browse, filter and inspect all financial transactions.' },
    'view-categories':   { title:'Categories',            subtitle:'Manage the category and subcategory hierarchy.' },
    'view-rules':        { title:'Categorization Rules',  subtitle:'Rules that determine how transactions are classified.' },
    'view-merchants':    { title:'Merchants',             subtitle:'Merchant mappings, aliases, MCC codes and defaults.' },
    'view-confidence':   { title:'Confidence Settings',   subtitle:'Configure confidence thresholds and scoring weights.' },
    'view-corrections':  { title:'User Corrections',      subtitle:'Review and act on user-submitted category corrections.' },
    'view-intelligence': { title:'Intelligence Rules',    subtitle:'Financial insight triggers based on spending patterns and balances.' },
    'view-users':        { title:'User Management',       subtitle:'Inspect user accounts, manage access status, and view profiles across all apps.' },
    'view-settings':     { title:'Settings',              subtitle:'API configuration and audit log.' },
  },

  init() {
    document.querySelectorAll('.nav-item').forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const view = item.dataset.view;
        if (view) Nav.switchTo(view);
      });
    });
    Nav.updateBadges();
  },

  switchTo(viewId) {
    // Update nav items
    document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
    const activeNav = document.querySelector(`[data-view="${viewId}"]`);
    if (activeNav) activeNav.classList.add('active');

    // Update views
    document.querySelectorAll('.content-view').forEach(v => { v.classList.remove('active'); v.classList.add('hidden'); });
    const activeView = document.getElementById(viewId);
    if (activeView) { activeView.classList.remove('hidden'); activeView.classList.add('active'); }

    state.activeView = viewId;

    // Update topbar
    const meta = Nav.viewMeta[viewId] || {};
    document.getElementById('page-title').textContent = meta.title || '';
    document.getElementById('page-subtitle').textContent = meta.subtitle || '';

    // Trigger view render
    const renders = {
      'view-dashboard':    Dashboard.render,
      'view-transactions': Transactions.render,
      'view-categories':   Categories.render,
      'view-rules':        Rules.render,
      'view-merchants':    Merchants.render,
      'view-confidence':   ConfidenceSettings.render,
      'view-corrections':  Corrections.render,
      'view-intelligence': Intelligence.render,
      'view-users':        Users.render,
      'view-settings':     Settings.render,
    };
    if (renders[viewId]) renders[viewId]();
    refreshIcons();
  },

  updateBadges() {
    const uncategorized = state.transactions.filter(t=>t.status==='uncategorized').length;
    const pending = state.corrections.filter(c=>c.status==='pending').length;
    const activeRules = state.rules.filter(r=>r.status==='active').length;
    const merchants = state.merchants.length;

    const el = (id, val) => { const e = document.getElementById(id); if(e) e.textContent = val; };
    el('nav-uncategorized-count', uncategorized);
    el('nav-corrections-count', pending);
    el('nav-rules-count', activeRules);
    el('nav-merchants-count', merchants);
    el('tab-corrections-count', pending);
    el('tab-suggestions-count', state.suggestedRules.filter(s=>s.status==='pending').length);
  }
};

// ============================================================
// DASHBOARD
// ============================================================
const Dashboard = {
  render() {
    Dashboard.renderKPIs();
    Dashboard.renderCharts();
    Dashboard.renderAlerts();
  },

  getStats() {
    const txns = state.transactions;
    const total = txns.length;
    const categorized = txns.filter(t=>t.status!=='uncategorized').length;
    const uncategorized = txns.filter(t=>t.status==='uncategorized').length;
    const categorizedPct = total > 0 ? Math.round(categorized / total * 100) : 0;

    const highBand = state.confidenceSettings.bands.high.min;
    const medBand  = state.confidenceSettings.bands.medium.min;
    const categorizedTxns = txns.filter(t=>t.status!=='uncategorized');
    const highConf = categorizedTxns.filter(t=>t.confidence>=highBand).length;
    const medConf  = categorizedTxns.filter(t=>t.confidence>=medBand && t.confidence<highBand).length;
    const lowConf  = categorizedTxns.filter(t=>t.confidence>0 && t.confidence<medBand).length;
    const withConf = highConf + medConf + lowConf;
    const highPct  = withConf > 0 ? Math.round(highConf/withConf*100) : 0;
    const medPct   = withConf > 0 ? Math.round(medConf/withConf*100)  : 0;
    const lowPct   = withConf > 0 ? Math.round(lowConf/withConf*100)  : 0;
    const pending  = state.corrections.filter(c=>c.status==='pending').length;

    return { total, categorized, uncategorized, categorizedPct, highConf, medConf, lowConf, highPct, medPct, lowPct, pending };
  },

  renderKPIs() {
    const s = Dashboard.getStats();
    const el = (id, val) => { const e = document.getElementById(id); if(e) e.textContent = val; };
    const usersCount = (Users._users && Users._users.length) ? Users._users.length : 1;
    el('kpi-total-users',         Utils.fmt.number(usersCount));
    el('kpi-total-txn',           Utils.fmt.number(s.total));
    el('kpi-categorized',         Utils.fmt.number(s.categorized));
    el('kpi-uncategorized',       Utils.fmt.number(s.uncategorized));
    el('kpi-high-conf',           s.highPct + '%');
    el('kpi-med-conf',            s.medPct + '%');
    el('kpi-low-conf',            s.lowPct + '%');
    el('kpi-pending-corrections', Utils.fmt.number(s.pending));

    const pctEl = document.getElementById('kpi-categorized-pct');
    if (pctEl) pctEl.innerHTML = `<i data-lucide="trending-up"></i> ${s.categorizedPct}% of total`;
    const usersTrendEl = document.getElementById('kpi-users-trend');
    if (usersTrendEl && Users._users && Users._users.length) {
      const admins = Users._users.filter(u => (u.role || '').toLowerCase() === 'admin' || (u.email || '').toLowerCase() === 'admin@themar.ip').length;
      const regular = usersCount - admins;
      usersTrendEl.textContent = `${admins} Admin${admins === 1 ? '' : 's'}${regular > 0 ? `, ${regular} App User${regular === 1 ? '' : 's'}` : ' (Only Admin)'}`;
    }
    refreshIcons();
  },

  renderCharts() {
    const txns = state.transactions;

    // 1. Categorization Rate (line over 14 days)
    const days = [];
    const catData = [];
    const uncatData = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date('2026-09-01');
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      const dayTxns = txns.filter(t=>t.date===dateStr);
      days.push(d.toLocaleDateString('en-GB',{day:'2-digit',month:'short'}));
      catData.push(dayTxns.filter(t=>t.status!=='uncategorized').length);
      uncatData.push(dayTxns.filter(t=>t.status==='uncategorized').length);
    }

    Dashboard._chart('chart-categorization-rate', 'line', {
      labels: days,
      datasets: [
        { label:'Categorized', data:catData, borderColor:'#10B981', backgroundColor:'rgba(16,185,129,0.1)', fill:true, tension:0.4, pointRadius:3 },
        { label:'Uncategorized', data:uncatData, borderColor:'#F43F5E', backgroundColor:'rgba(244,63,94,0.1)', fill:true, tension:0.4, pointRadius:3 },
      ]
    }, { scales:{ y:{ beginAtZero:true, grid:{color:'rgba(255,255,255,0.05)'}, ticks:{color:'#94A3B8'} }, x:{ grid:{color:'rgba(255,255,255,0.05)'}, ticks:{color:'#94A3B8'} } } });

    // 2. Confidence distribution (doughnut)
    const s = Dashboard.getStats();
    Dashboard._chart('chart-confidence-dist', 'doughnut', {
      labels: ['High (≥90%)', 'Medium (70–89%)', 'Low (<70%)'],
      datasets:[{ data:[s.highConf, s.medConf, s.lowConf], backgroundColor:['#10B981','#F59E0B','#F43F5E'], borderWidth:2, borderColor:'#1E293B' }]
    }, { plugins:{ legend:{ position:'bottom', labels:{color:'#94A3B8', padding:12, font:{size:11}} } }, cutout:'65%' });

    // 3. Transactions by category (bar)
    const catCounts = {};
    state.categories.forEach(c=>{ catCounts[c.id]=0; });
    txns.forEach(t=>{ if(t.categoryId && catCounts[t.categoryId]!==undefined) catCounts[t.categoryId]++; });
    const sortedCats = Object.entries(catCounts).sort((a,b)=>b[1]-a[1]).slice(0,8);
    const catColors = ['#3B82F6','#10B981','#8B5CF6','#F59E0B','#F43F5E','#06B6D4','#F97316','#EC4899'];
    Dashboard._chart('chart-by-category', 'bar', {
      labels: sortedCats.map(([id])=>Utils.getCategoryName(id)),
      datasets:[{ data:sortedCats.map(([,cnt])=>cnt), backgroundColor:catColors, borderRadius:4, borderSkipped:false }]
    }, { plugins:{legend:{display:false}}, scales:{ y:{beginAtZero:true,grid:{color:'rgba(255,255,255,0.05)'},ticks:{color:'#94A3B8'}}, x:{grid:{display:false},ticks:{color:'#94A3B8',maxRotation:30}} } });

    // 4. Uncategorized trend
    const uncatTrend = [];
    const days2 = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date('2026-09-01');
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split('T')[0];
      days2.push(d.toLocaleDateString('en-GB',{day:'2-digit',month:'short'}));
      uncatTrend.push(txns.filter(t=>t.date===dateStr && t.status==='uncategorized').length);
    }
    Dashboard._chart('chart-uncategorized-trend', 'bar', {
      labels: days2,
      datasets:[{ label:'Uncategorized', data:uncatTrend, backgroundColor:'rgba(244,63,94,0.7)', borderRadius:4 }]
    }, { plugins:{legend:{display:false}}, scales:{ y:{beginAtZero:true,grid:{color:'rgba(255,255,255,0.05)'},ticks:{color:'#94A3B8'}}, x:{grid:{display:false},ticks:{color:'#94A3B8',maxRotation:30}} } });
  },

  _chart(id, type, data, options={}) {
    const canvas = document.getElementById(id);
    if (!canvas) return;
    if (state.charts[id]) { state.charts[id].destroy(); }
    state.charts[id] = new Chart(canvas, {
      type,
      data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend:{ display:type!=='bar', labels:{color:'#94A3B8',font:{size:11}} }, tooltip:{callbacks:{}} },
        ...options
      }
    });
  },

  renderAlerts() {
    // Top uncategorized merchants (narrations)
    const uncatTxns = state.transactions.filter(t=>t.status==='uncategorized');
    const narrationCounts = {};
    uncatTxns.forEach(t=>{ const k=t.narration; narrationCounts[k]=(narrationCounts[k]||0)+1; });
    const topUncat = Object.entries(narrationCounts).sort((a,b)=>b[1]-a[1]).slice(0,4);
    document.getElementById('alert-uncategorized-merchants').innerHTML = topUncat.length ? topUncat.map(([n,c])=>
      `<div class="alert-item"><span class="alert-item-merchant">${n}</span><span class="alert-item-count">${c} txn</span></div>`
    ).join('') : '<p style="font-size:12px;color:var(--text-dim);">No uncategorized merchants detected.</p>';

    // High correction rate
    const highCorr = state.merchants.filter(m=>m.correctionRate>2).sort((a,b)=>b.correctionRate-a.correctionRate).slice(0,4);
    document.getElementById('alert-high-correction-merchants').innerHTML = highCorr.length ? highCorr.map(m=>
      `<div class="alert-item"><span class="alert-item-merchant">${m.name}</span><span class="alert-item-count">${m.correctionRate}% correction</span></div>`
    ).join('') : '<p style="font-size:12px;color:var(--text-dim);">No merchants with high correction rate.</p>';

    // Suggested rules
    const pending = state.suggestedRules.filter(s=>s.status==='pending');
    document.getElementById('alert-suggested-rules').innerHTML = pending.length ? pending.map(s=>{
      const from = `${Utils.getCategoryName(s.currentCategoryId)}`;
      const to   = `${Utils.getCategoryName(s.suggestedCategoryId)} → ${Utils.getSubcategoryName(s.suggestedSubcategoryId)}`;
      return `<div class="alert-item"><span class="alert-item-merchant">${s.merchantName}: ${from} → ${to}</span><span class="alert-item-count">${s.occurrences} corrections</span></div>`;
    }).join('') : '<p style="font-size:12px;color:var(--text-dim);">No new rule suggestions.</p>';

    // Intelligence rules firing often
    const freqIntel = [...state.intelligenceRules].sort((a,b)=>b.fireCount-a.fireCount).slice(0,4);
    document.getElementById('alert-intel-rules').innerHTML = freqIntel.map(r=>
      `<div class="alert-item"><span class="alert-item-merchant">${r.name}</span><span class="alert-item-count">${r.fireCount} fires</span></div>`
    ).join('');
  }
};

// ============================================================
// TRANSACTIONS
// ============================================================
const Transactions = {
  _filtered: [],

  render() {
    Transactions._applyFilters();
    Transactions._populateCategoryFilter();
    Transactions._renderTable();
  },

  _populateCategoryFilter() {
    const sel = document.getElementById('txn-filter-category');
    if (!sel || sel.options.length > 1) return;
    state.categories.forEach(c=>{
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = c.name;
      sel.appendChild(opt);
    });
  },

  _applyFilters() {
    let txns = [...state.transactions];
    const search = state.txnSearch.toLowerCase();
    if (search) txns = txns.filter(t=>t.merchantName.toLowerCase().includes(search)||t.narration.toLowerCase().includes(search));
    if (state.txnFilterCategory) txns = txns.filter(t=>t.categoryId===state.txnFilterCategory);
    if (state.txnFilterSource)   txns = txns.filter(t=>t.source===state.txnFilterSource);
    if (state.txnFilterType)     txns = txns.filter(t=>t.type===state.txnFilterType);
    if (state.txnFilterStatus)   txns = txns.filter(t=>t.status===state.txnFilterStatus);
    if (state.txnFilterConfidence) {
      const band = state.confidenceSettings.bands;
      if (state.txnFilterConfidence==='high')   txns = txns.filter(t=>t.confidence>=band.high.min);
      if (state.txnFilterConfidence==='medium')  txns = txns.filter(t=>t.confidence>=band.medium.min && t.confidence<band.high.min);
      if (state.txnFilterConfidence==='low')     txns = txns.filter(t=>t.confidence>0 && t.confidence<band.medium.min);
    }
    // Sort newest first
    txns.sort((a,b)=>new Date(b.date)-new Date(a.date));
    Transactions._filtered = txns;
  },

  _renderTable() {
    const filtered = Transactions._filtered;
    const page = state.txnPage;
    const size = state.txnPageSize;
    const paged = Utils.paginate(filtered, page, size);
    const total = filtered.length;

    const tbody = document.getElementById('tbody-transactions');
    if (paged.length === 0) {
      tbody.innerHTML = `<tr><td colspan="12"><div class="empty-state"><i data-lucide="inbox" class="empty-state-icon"></i><p class="empty-state-title">No transactions found</p><p class="empty-state-subtitle">Try adjusting your search or filters.</p></div></td></tr>`;
      refreshIcons();
    } else {
      tbody.innerHTML = paged.map(t=>`
        <tr class="clickable" data-txn-id="${t.id}">
          <td style="white-space:nowrap;font-size:12px;color:var(--text-muted);">${Utils.fmt.date(t.date)}</td>
          <td style="font-weight:500;">${t.merchantName}</td>
          <td style="font-size:12px;color:var(--text-muted);max-width:180px;" class="truncate" title="${t.narration}">${t.narration}</td>
          <td style="font-weight:600;white-space:nowrap;">${Utils.fmt.omr(t.amount)}</td>
          <td><span class="badge ${t.type==='debit'?'badge-inactive':'badge-active'}" style="font-size:10px;">${t.type}</span></td>
          <td style="font-size:12px;color:var(--text-muted);white-space:nowrap;">${Utils.fmt.omr(t.balanceAfter)}</td>
          <td>${t.categoryId?Utils.getCategoryName(t.categoryId):'—'}</td>
          <td style="font-size:12px;color:var(--text-muted);">${t.subcategoryId?Utils.getSubcategoryName(t.subcategoryId):'—'}</td>
          <td>${Utils.confidenceBadge(t.confidence)}</td>
          <td>${Utils.sourceBadge(t.source)}</td>
          <td>${Utils.statusBadge(t.status)}</td>
          <td><button class="btn btn-xs btn-secondary txn-detail-btn" data-txn-id="${t.id}"><i data-lucide="eye" style="width:12px;"></i></button></td>
        </tr>`).join('');
    }

    document.getElementById('txn-count-label').textContent = `${total} transaction${total!==1?'s':''}`;
    document.getElementById('txn-pagination-info').textContent = `Showing ${paged.length} of ${total}`;
    document.getElementById('txn-page-badge').textContent = `Page ${page} of ${Utils.totalPages(filtered, size)}`;
    document.getElementById('txn-prev-btn').disabled = page <= 1;
    document.getElementById('txn-next-btn').disabled = page >= Utils.totalPages(filtered, size);

    refreshIcons();

    tbody.querySelectorAll('.txn-detail-btn, tr.clickable').forEach(el=>{
      el.addEventListener('click', (e)=>{
        e.stopPropagation();
        const id = el.dataset.txnId || el.closest('tr')?.dataset.txnId;
        if (id) Transactions.openDrawer(id);
      });
    });
  },

  openDrawer(txnId) {
    const txn = state.transactions.find(t=>t.id===txnId);
    if (!txn) return;
    const catName = Utils.getCategoryName(txn.categoryId);
    const subName = Utils.getSubcategoryName(txn.subcategoryId);
    const scores = txn.scoreBreakdown || {};
    const total = Object.values(scores).reduce((a,b)=>a+b,0);

    document.getElementById('txn-drawer-body').innerHTML = `
      <div class="drawer-section">
        <div class="drawer-section-title">Transaction</div>
        <div class="detail-row"><span class="detail-label">Date</span><span class="detail-value">${Utils.fmt.date(txn.date)}</span></div>
        <div class="detail-row"><span class="detail-label">Merchant</span><span class="detail-value" style="font-weight:600;">${txn.merchantName}</span></div>
        <div class="detail-row"><span class="detail-label">Narration</span><span class="detail-value" style="font-family:monospace;font-size:12px;">${txn.narration}</span></div>
        <div class="detail-row"><span class="detail-label">Amount</span><span class="detail-value" style="font-weight:700;font-size:18px;">${Utils.fmt.omr(txn.amount)}</span></div>
        <div class="detail-row"><span class="detail-label">Type</span><span class="detail-value">${Utils.statusBadge(txn.type)}</span></div>
        <div class="detail-row"><span class="detail-label">Balance After</span><span class="detail-value">${Utils.fmt.omr(txn.balanceAfter)}</span></div>
        ${txn.isRecurring ? '<div class="detail-row"><span class="detail-label">Flags</span><span class="badge badge-approved" style="font-size:10px;"><i data-lucide="repeat" style="width:10px;"></i> Recurring</span></div>' : ''}
      </div>

      <div class="drawer-section">
        <div class="drawer-section-title">Categorization</div>
        <div class="detail-row"><span class="detail-label">Category</span><span class="detail-value" style="font-weight:600;">${catName}</span></div>
        <div class="detail-row"><span class="detail-label">Subcategory</span><span class="detail-value">${subName}</span></div>
        <div class="detail-row"><span class="detail-label">Confidence</span><span class="detail-value">${Utils.confidenceBadge(txn.confidence)}</span></div>
        <div class="detail-row"><span class="detail-label">Source</span><span class="detail-value">${Utils.sourceBadge(txn.source)}</span></div>
        <div class="detail-row"><span class="detail-label">Status</span><span class="detail-value">${Utils.statusBadge(txn.status)}</span></div>
      </div>

      <div class="drawer-section">
        <div class="drawer-section-title">Why was this categorized?</div>
        <p style="font-size:12px;color:var(--text-muted);margin-bottom:12px;">Confidence score breakdown by signal type.</p>
        <div class="score-breakdown">
          ${[
            ['Merchant Match',  scores.merchantMatch],
            ['MCC Match',       scores.mccMatch],
            ['Narration Match', scores.narrationMatch],
            ['Historical Match',scores.historicalMatch],
            ['Amount Pattern',  scores.amountPattern],
          ].map(([label, val])=>`
            <div class="score-row">
              <span class="score-label">${label}</span>
              <div style="flex:1;margin:0 12px;height:4px;background:rgba(255,255,255,0.06);border-radius:2px;overflow:hidden;">
                <div style="width:${val}%;height:100%;background:var(--accent-blue);border-radius:2px;"></div>
              </div>
              <span class="score-value">+${val}</span>
            </div>`).join('')}
          <div class="score-row score-total">
            <span class="score-label">Total Confidence</span>
            <span></span>
            <span class="score-value" style="color:var(--accent-emerald);font-weight:700;">${total}</span>
          </div>
        </div>
      </div>
    `;
    Drawer.open('txn-drawer');
  },

  initEvents() {
    document.getElementById('txn-search').addEventListener('input', (e)=>{ state.txnSearch=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-filter-category').addEventListener('change', (e)=>{ state.txnFilterCategory=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-filter-source').addEventListener('change', (e)=>{ state.txnFilterSource=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-filter-confidence').addEventListener('change', (e)=>{ state.txnFilterConfidence=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-filter-type').addEventListener('change', (e)=>{ state.txnFilterType=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-filter-status').addEventListener('change', (e)=>{ state.txnFilterStatus=e.target.value; state.txnPage=1; Transactions._applyFilters(); Transactions._renderTable(); });
    document.getElementById('txn-prev-btn').addEventListener('click', ()=>{ if(state.txnPage>1){ state.txnPage--; Transactions._renderTable(); } });
    document.getElementById('txn-next-btn').addEventListener('click', ()=>{ if(state.txnPage<Utils.totalPages(Transactions._filtered,state.txnPageSize)){ state.txnPage++; Transactions._renderTable(); } });
    document.getElementById('txn-drawer-close').addEventListener('click', ()=>Drawer.close('txn-drawer'));
  }
};

// ============================================================
// CATEGORIES
// ============================================================
const Categories = {
  _expandedIds: new Set(),

  render() {
    const container = document.getElementById('category-tree');
    container.innerHTML = state.categories.sort((a,b)=>a.order-b.order).map(cat => {
      const subs = state.subcategories.filter(s=>s.categoryId===cat.id).sort((a,b)=>a.order-b.order);
      const txnCount = state.transactions.filter(t=>t.categoryId===cat.id).length;
      const expanded = Categories._expandedIds.has(cat.id);
      return `
        <div class="category-item" data-cat-id="${cat.id}">
          <div class="category-row ${cat.enabled?'':'category-disabled'}" style="border-left:3px solid ${cat.color};">
            <button class="category-expand-btn" data-toggle="${cat.id}" style="color:${cat.color};">
              <i data-lucide="${expanded?'chevron-down':'chevron-right'}" style="width:14px;"></i>
            </button>
            <i data-lucide="${cat.icon}" class="category-icon" style="color:${cat.color};width:16px;"></i>
            <span class="category-name">${cat.name}</span>
            <span class="category-count">${txnCount} txn</span>
            <div class="category-actions">
              <button class="btn btn-xs btn-ghost add-subcat-btn" data-cat-id="${cat.id}" title="Add subcategory"><i data-lucide="plus" style="width:12px;"></i></button>
              <button class="btn btn-xs btn-ghost delete-cat-btn" data-cat-id="${cat.id}" title="Delete Category" style="color: #F43F5E;"><i data-lucide="trash-2" style="width:12px;"></i></button>
            </div>
          </div>
          <div class="subcategory-list ${expanded?'':'hidden'}">
            ${subs.map(s=>`
              <div class="subcategory-item">
                <div class="subcategory-row ${s.enabled?'':'category-disabled'}">
                  <i data-lucide="corner-down-right" style="width:12px;color:var(--text-dim);margin:0 6px 0 28px;"></i>
                  <span class="category-name" style="font-size:13px;">${s.name}</span>
                  <span class="category-count">${state.transactions.filter(t=>t.subcategoryId===s.id).length} txn</span>
                  <div class="category-actions">
                    <button class="btn btn-xs btn-ghost delete-subcat-btn" data-subcat-id="${s.id}" title="Delete Subcategory" style="color: #F43F5E;"><i data-lucide="trash-2" style="width:12px;"></i></button>
                  </div>
                </div>
              </div>`).join('')}
            <div class="subcategory-item">
              <div class="subcategory-row" style="opacity:0.6;">
                <i data-lucide="plus" style="width:12px;color:var(--accent-blue);margin:0 6px 0 28px;"></i>
                <button class="btn btn-xs btn-ghost add-subcat-btn" data-cat-id="${cat.id}" style="color:var(--accent-blue);font-size:12px;">Add subcategory</button>
              </div>
            </div>
          </div>
        </div>`;
    }).join('');
    refreshIcons();
    Categories._bindEvents();
  },

  _bindEvents() {
    document.querySelectorAll('.category-expand-btn').forEach(btn=>{
      btn.addEventListener('click', ()=>{
        const catId = btn.dataset.toggle;
        if (Categories._expandedIds.has(catId)) Categories._expandedIds.delete(catId);
        else Categories._expandedIds.add(catId);
        Categories.render();
      });
    });
    document.querySelectorAll('.add-subcat-btn').forEach(btn=>{
      btn.addEventListener('click', ()=>Categories.openModal(null, btn.dataset.catId));
    });
    document.querySelectorAll('.delete-cat-btn').forEach(btn=>{
      btn.addEventListener('click', async ()=>{
        const catId = btn.dataset.catId;
        const cat = state.categories.find(c=>c.id===catId);
        if (cat && confirm(`Are you sure you want to delete category "${cat.name}" from themarip.db?`)) {
          try {
            const res = await fetch(`${THEMAR_API_BASE}/statements/categories/${catId}`, { method: 'DELETE' });
            if (res.ok) {
              await loadCategoryRulesFromDb();
              Categories.render();
              Toast.success(`Category "${cat.name}" deleted from themarip.db.`);
            }
          } catch(e) { console.error(e); }
        }
      });
    });
    document.querySelectorAll('.delete-subcat-btn').forEach(btn=>{
      btn.addEventListener('click', async ()=>{
        const subId = btn.dataset.subcatId;
        const sub = state.subcategories.find(s=>s.id===subId);
        if (sub && confirm(`Are you sure you want to delete subcategory "${sub.name}" from themarip.db?`)) {
          try {
            const res = await fetch(`${THEMAR_API_BASE}/statements/categories/${subId}`, { method: 'DELETE' });
            if (res.ok) {
              await loadCategoryRulesFromDb();
              Categories.render();
              Toast.success(`Subcategory "${sub.name}" deleted from themarip.db.`);
            }
          } catch(e) { console.error(e); }
        }
      });
    });
  },

  openModal(catId, parentCatId) {
    const isSubcat = !!parentCatId;
    const editingCat = catId ? state.categories.find(c=>c.id===catId) : null;

    document.getElementById('category-modal-title').textContent = editingCat ? 'Edit Category' : (isSubcat ? 'Add Subcategory' : 'Add Category');
    document.getElementById('cat-form-name-label').textContent = isSubcat ? 'Subcategory Name *' : 'Category Name *';
    document.getElementById('cat-form-icon-group').classList.toggle('hidden', isSubcat);
    document.getElementById('cat-form-id').value = catId || '';
    document.getElementById('cat-form-parent-id').value = parentCatId || '';
    document.getElementById('cat-form-name').value = editingCat ? editingCat.name : '';
    document.getElementById('cat-form-icon').value = editingCat ? editingCat.icon : '';
    Modal.open('category-modal-overlay');
  },

  async saveModal() {
    const id = document.getElementById('cat-form-id').value;
    const parentId = document.getElementById('cat-form-parent-id').value;
    const name = document.getElementById('cat-form-name').value.trim();
    const icon = document.getElementById('cat-form-icon').value.trim() || 'tag';
    if (!name) { Toast.error('Name is required.'); return; }

    if (parentId) {
      // Subcategory (ParentId != null)
      if (id) {
        const sub = state.subcategories.find(s=>s.id===id);
        if (sub) { sub.name=name; Toast.success(`Subcategory updated.`); }
      } else {
        try {
          const res = await fetch(THEMAR_API_BASE + '/statements/categories', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ parentId: parentId, name: name, icon: 'corner-down-right' })
          });
          if (res.ok) {
            await loadCategoryRulesFromDb();
            Toast.success(`Subcategory "${name}" created and saved to themarip.db.`);
          }
        } catch(e) {
          console.error(e);
        }
      }
    } else {
      // Root Category (ParentId == null)
      if (id) {
        const cat = state.categories.find(c=>c.id===id);
        if (cat) { cat.name=name; cat.icon=icon; Toast.success(`Category updated.`); }
      } else {
        try {
          const colors = ['#10B981','#3B82F6','#8B5CF6','#F59E0B','#F43F5E','#06B6D4','#F97316'];
          const color = colors[state.categories.length % colors.length];
          const res = await fetch(THEMAR_API_BASE + '/statements/categories', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ parentId: null, name: name, icon: icon, color: color })
          });
          if (res.ok) {
            await loadCategoryRulesFromDb();
            Toast.success(`Category "${name}" created and saved to themarip.db.`);
          }
        } catch(e) {
          console.error(e);
        }
      }
    }
    Modal.close('category-modal-overlay');
    Categories.render();
    Nav.updateBadges();
  },

  initEvents() {
    document.getElementById('btn-add-category').addEventListener('click', ()=>Categories.openModal(null, null));
    document.getElementById('category-modal-save').addEventListener('click', Categories.saveModal);
    document.getElementById('category-modal-cancel').addEventListener('click', ()=>Modal.close('category-modal-overlay'));
    document.getElementById('category-modal-close').addEventListener('click', ()=>Modal.close('category-modal-overlay'));
  }
};

// ============================================================
// CATEGORIZATION RULES
// ============================================================
const Rules = {
  _filtered: [],
  FIELDS: ['merchant_name','merchant_id','narration','mcc','type','amount','currency'],
  OPERATORS: ['contains','equals','starts_with','ends_with','greater_than','less_than','between'],
  FIELD_LABELS: { merchant_name:'Merchant Name', merchant_id:'Merchant ID', narration:'Narration', mcc:'MCC Code', type:'Transaction Type', amount:'Amount (OMR)', currency:'Currency' },
  OP_LABELS: { contains:'Contains', equals:'Equals', starts_with:'Starts With', ends_with:'Ends With', greater_than:'Greater Than', less_than:'Less Than', between:'Between' },

  render() {
    Rules._applyFilters();
    Rules._renderTable();
  },

  _applyFilters() {
    let rules = [...state.rules];
    if (state.rulesSearch) rules = rules.filter(r=>r.name.toLowerCase().includes(state.rulesSearch.toLowerCase()));
    if (state.rulesFilterStatus) rules = rules.filter(r=>r.status===state.rulesFilterStatus);
    rules.sort((a,b)=>b.priority-a.priority);
    Rules._filtered = rules;
  },

  _renderTable() {
    const filtered = Rules._filtered;
    const paged = Utils.paginate(filtered, state.rulesPage, state.rulesPageSize);
    const tbody = document.getElementById('tbody-rules');

    if (paged.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><p class="empty-state-title">No rules found</p></div></td></tr>`;
    } else {
      tbody.innerHTML = paged.map(r=>{
        const condSummary = r.conditions.map(c=>`${Rules.FIELD_LABELS[c.field]||c.field} ${Rules.OP_LABELS[c.operator]||c.operator} "${c.value}"`).join(' AND ');
        return `<tr>
          <td style="font-weight:600;">${r.name}</td>
          <td style="font-size:12px;color:var(--text-muted);max-width:200px;" class="truncate" title="${condSummary}">${condSummary}</td>
          <td><span style="font-weight:500;">${Utils.getCategoryName(r.categoryId)}</span><span style="color:var(--text-dim);font-size:12px;"> → ${Utils.getSubcategoryName(r.subcategoryId)}</span></td>
          <td>${Utils.confidenceBadge(r.confidence)}</td>
          <td style="text-align:center;">${Utils.priorityBadge(r.priority)}</td>
          <td style="color:var(--text-muted);font-size:12px;">${Utils.fmt.number(r.matchCount)}</td>
          <td>${Utils.statusBadge(r.status)}</td>
          <td>
            <div style="display:flex;gap:6px;">
              <button class="btn btn-xs btn-secondary rule-edit-btn" data-rule-id="${r.id}" title="Edit"><i data-lucide="pencil" style="width:12px;"></i></button>
              <button class="btn btn-xs btn-ghost rule-toggle-btn" data-rule-id="${r.id}" title="${r.status==='active'?'Deactivate':'Activate'}" style="color:${r.status==='active'?'var(--accent-amber)':'var(--accent-emerald)'}"><i data-lucide="${r.status==='active'?'pause-circle':'play-circle'}" style="width:12px;"></i></button>
              <button class="btn btn-xs btn-ghost rule-delete-btn" data-rule-id="${r.id}" title="Delete" style="color:var(--accent-rose);"><i data-lucide="trash-2" style="width:12px;"></i></button>
            </div>
          </td>
        </tr>`;
      }).join('');
    }

    document.getElementById('rules-pagination-info').textContent = `Showing ${paged.length} of ${filtered.length}`;
    document.getElementById('rules-page-badge').textContent = `Page ${state.rulesPage} of ${Utils.totalPages(filtered, state.rulesPageSize)}`;
    document.getElementById('rules-prev-btn').disabled = state.rulesPage <= 1;
    document.getElementById('rules-next-btn').disabled = state.rulesPage >= Utils.totalPages(filtered, state.rulesPageSize);

    refreshIcons();
    tbody.querySelectorAll('.rule-edit-btn').forEach(btn=>btn.addEventListener('click', ()=>Rules.openModal(btn.dataset.ruleId)));
    tbody.querySelectorAll('.rule-toggle-btn').forEach(btn=>btn.addEventListener('click', ()=>Rules.toggleRule(btn.dataset.ruleId)));
    tbody.querySelectorAll('.rule-delete-btn').forEach(btn=>btn.addEventListener('click', ()=>Rules.deleteRule(btn.dataset.ruleId)));
  },

  openModal(ruleId) {
    const rule = ruleId ? state.rules.find(r=>r.id===ruleId) : null;
    document.getElementById('rule-modal-title').textContent = rule ? 'Edit Rule' : 'Create Categorization Rule';
    document.getElementById('rule-form-id').value = rule?.id || '';
    document.getElementById('rule-form-name').value = rule?.name || '';
    document.getElementById('rule-form-priority').value = rule?.priority || 50;
    document.getElementById('rule-form-confidence').value = rule?.confidence || 85;
    document.getElementById('rule-form-status').value = rule?.status || 'active';

    // Populate THEN category selects
    Rules._populateCategorySelects();

    // Populate conditions
    document.getElementById('rule-conditions-container').innerHTML = '';
    const conditions = rule ? rule.conditions : [{ field:'merchant_name', operator:'contains', value:'', logic:'AND' }];
    conditions.forEach((cond, idx) => Rules._addConditionRow(cond, idx));

    if (rule) {
      document.getElementById('rule-form-category').value = rule.categoryId;
      Rules._updateSubcategorySelect('rule-form-category', 'rule-form-subcategory', rule.subcategoryId);
    }

    Modal.open('rule-modal-overlay');
  },

  _populateCategorySelects() {
    const catSel = document.getElementById('rule-form-category');
    catSel.innerHTML = '<option value="">Select category…</option>';
    state.categories.filter(c=>c.enabled).forEach(c=>{
      const opt = document.createElement('option');
      opt.value = c.id; opt.textContent = c.name; catSel.appendChild(opt);
    });
    catSel.onchange = ()=>Rules._updateSubcategorySelect('rule-form-category','rule-form-subcategory','');
    Rules._updateSubcategorySelect('rule-form-category','rule-form-subcategory','');
  },

  _updateSubcategorySelect(catSelId, subSelId, selectedSubId) {
    const catId = document.getElementById(catSelId).value;
    const subSel = document.getElementById(subSelId);
    subSel.innerHTML = '<option value="">Select subcategory…</option>';
    Utils.getSubcatsForCategory(catId).filter(s=>s.enabled).forEach(s=>{
      const opt = document.createElement('option');
      opt.value = s.id; opt.textContent = s.name;
      if (s.id === selectedSubId) opt.selected = true;
      subSel.appendChild(opt);
    });
  },

  _addConditionRow(cond, idx) {
    const container = document.getElementById('rule-conditions-container');
    const div = document.createElement('div');
    div.className = 'condition-block';
    div.dataset.idx = idx;
    div.innerHTML = `
      <div class="condition-row">
        ${idx > 0 ? `<select class="form-control condition-logic" style="width:80px;flex:0 0 80px;"><option value="AND" ${cond.logic==='AND'?'selected':''}>AND</option><option value="OR" ${cond.logic==='OR'?'selected':''}>OR</option></select>` : '<span style="width:80px;flex:0 0 80px;font-size:12px;font-weight:600;color:var(--accent-blue);">IF</span>'}
        <select class="form-control condition-field" style="flex:1;">
          ${Object.entries(Rules.FIELD_LABELS).map(([v,l])=>`<option value="${v}" ${cond.field===v?'selected':''}>${l}</option>`).join('')}
        </select>
        <select class="form-control condition-operator" style="flex:1;">
          ${Object.entries(Rules.OP_LABELS).map(([v,l])=>`<option value="${v}" ${cond.operator===v?'selected':''}>${l}</option>`).join('')}
        </select>
        <input type="text" class="form-control condition-value" style="flex:1;" value="${cond.value||''}" placeholder="value…">
        ${idx > 0 ? `<button class="btn btn-xs btn-ghost remove-condition-btn" style="color:var(--accent-rose);"><i data-lucide="x" style="width:12px;"></i></button>` : ''}
      </div>`;
    container.appendChild(div);
    if (idx > 0) {
      div.querySelector('.remove-condition-btn').addEventListener('click', ()=>{ div.remove(); refreshIcons(); });
    }
    refreshIcons();
  },

  saveModal() {
    const id = document.getElementById('rule-form-id').value;
    const name = document.getElementById('rule-form-name').value.trim();
    const priority = parseInt(document.getElementById('rule-form-priority').value);
    const confidence = parseInt(document.getElementById('rule-form-confidence').value);
    const status = document.getElementById('rule-form-status').value;
    const categoryId = document.getElementById('rule-form-category').value;
    const subcategoryId = document.getElementById('rule-form-subcategory').value;

    if (!name) { Toast.error('Rule name is required.'); return; }
    if (!categoryId) { Toast.error('Please select a category.'); return; }

    const conditionBlocks = document.querySelectorAll('#rule-conditions-container .condition-block');
    const conditions = [];
    conditionBlocks.forEach((block, idx) => {
      const logic = block.querySelector('.condition-logic')?.value || 'AND';
      const field = block.querySelector('.condition-field').value;
      const operator = block.querySelector('.condition-operator').value;
      const value = block.querySelector('.condition-value').value.trim();
      if (value) conditions.push({ field, operator, value, logic: idx===0?'AND':logic });
    });
    if (conditions.length === 0) { Toast.error('Add at least one condition.'); return; }

    if (id) {
      const rule = state.rules.find(r=>r.id===id);
      if (rule) {
        AuditLog.record('UPDATE','Rule',`Updated rule: ${name}`);
        Object.assign(rule, { name, conditions, categoryId, subcategoryId, confidence, priority, status });
        Toast.success(`Rule "${name}" updated.`);
      }
    } else {
      const newRule = { id:'rule-'+Date.now(), name, conditions, categoryId, subcategoryId, confidence, priority, status, matchCount:0 };
      state.rules.push(newRule);
      AuditLog.record('CREATE','Rule',`Created rule: ${name} → ${Utils.getCategoryName(categoryId)} / ${Utils.getSubcategoryName(subcategoryId)}`);
      Toast.success(`Rule "${name}" created.`);
    }
    Modal.close('rule-modal-overlay');
    Rules.render();
    Nav.updateBadges();
  },

  toggleRule(ruleId) {
    const rule = state.rules.find(r=>r.id===ruleId);
    if (!rule) return;
    rule.status = rule.status==='active' ? 'inactive' : 'active';
    AuditLog.record('TOGGLE','Rule',`${rule.status==='active'?'Activated':'Deactivated'} rule: ${rule.name}`);
    Toast.success(`Rule "${rule.name}" ${rule.status}.`);
    Rules.render();
    Nav.updateBadges();
  },

  async deleteRule(ruleId) {
    const rule = state.rules.find(r=>r.id===ruleId);
    if (!rule) return;
    const confirmed = await Confirm.show('Delete Rule', `Are you sure you want to delete "${rule.name}"? This cannot be undone.`, 'Delete', true);
    if (confirmed) {
      state.rules = state.rules.filter(r=>r.id!==ruleId);
      AuditLog.record('DELETE','Rule',`Deleted rule: ${rule.name}`);
      Toast.success(`Rule deleted.`);
      Rules.render();
      Nav.updateBadges();
    }
  },

  initEvents() {
    document.getElementById('btn-add-rule').addEventListener('click', ()=>Rules.openModal(null));
    document.getElementById('rule-modal-save').addEventListener('click', Rules.saveModal);
    document.getElementById('rule-modal-cancel').addEventListener('click', ()=>Modal.close('rule-modal-overlay'));
    document.getElementById('rule-modal-close').addEventListener('click', ()=>Modal.close('rule-modal-overlay'));
    document.getElementById('btn-add-condition').addEventListener('click', ()=>{
      const count = document.querySelectorAll('#rule-conditions-container .condition-block').length;
      Rules._addConditionRow({ field:'merchant_name', operator:'contains', value:'', logic:'AND' }, count);
    });
    document.getElementById('rules-search').addEventListener('input', (e)=>{ state.rulesSearch=e.target.value; state.rulesPage=1; Rules._applyFilters(); Rules._renderTable(); });
    document.getElementById('rules-filter-status').addEventListener('change', (e)=>{ state.rulesFilterStatus=e.target.value; state.rulesPage=1; Rules._applyFilters(); Rules._renderTable(); });
    document.getElementById('rules-prev-btn').addEventListener('click', ()=>{ if(state.rulesPage>1){ state.rulesPage--; Rules._renderTable(); } });
    document.getElementById('rules-next-btn').addEventListener('click', ()=>{ const tp=Utils.totalPages(Rules._filtered,state.rulesPageSize); if(state.rulesPage<tp){ state.rulesPage++; Rules._renderTable(); } });
  }
};

// ============================================================
// MERCHANTS
// ============================================================
const Merchants = {
  _filtered: [],

  render() {
    Merchants._applyFilters();
    Merchants._populateCategoryFilter();
    Merchants._renderTable();
  },

  _populateCategoryFilter() {
    const sel = document.getElementById('merchants-filter-category');
    if (!sel || sel.options.length > 1) return;
    state.categories.forEach(c=>{ const o=document.createElement('option'); o.value=c.id; o.textContent=c.name; sel.appendChild(o); });
  },

  _applyFilters() {
    let merchants = [...state.merchants];
    if (state.merchantsSearch) {
      const s = state.merchantsSearch.toLowerCase();
      merchants = merchants.filter(m=>m.name.toLowerCase().includes(s)||m.aliases.some(a=>a.toLowerCase().includes(s)));
    }
    if (state.merchantsFilterStatus) merchants = merchants.filter(m=>m.status===state.merchantsFilterStatus);
    if (state.merchantsFilterCategory) merchants = merchants.filter(m=>m.defaultCategoryId===state.merchantsFilterCategory);
    Merchants._filtered = merchants;
  },

  _renderTable() {
    const paged = Utils.paginate(Merchants._filtered, state.merchantsPage, state.merchantsPageSize);
    const tbody = document.getElementById('tbody-merchants');

    if (paged.length === 0) {
      tbody.innerHTML = `<tr><td colspan="9"><div class="empty-state"><p class="empty-state-title">No merchants found</p></div></td></tr>`;
    } else {
      tbody.innerHTML = paged.map(m=>`
        <tr>
          <td style="font-weight:600;">${m.name}</td>
          <td style="font-size:11px;color:var(--text-dim);">${m.aliases.slice(0,3).map(a=>`<span class="alias-chip">${a}</span>`).join('')}${m.aliases.length>3?`<span class="alias-chip">+${m.aliases.length-3}</span>`:''}</td>
          <td style="font-family:monospace;font-size:12px;color:var(--text-muted);">${m.mcc||'—'}</td>
          <td>${Utils.getCategoryName(m.defaultCategoryId)}<span style="color:var(--text-dim);font-size:12px;"> → ${Utils.getSubcategoryName(m.defaultSubcategoryId)}</span></td>
          <td>${Utils.confidenceBadge(m.defaultConfidence)}</td>
          <td style="color:var(--text-muted);">${Utils.fmt.number(m.txCount)}</td>
          <td>
            <span style="color:${m.correctionRate>3?'var(--accent-rose)':m.correctionRate>1?'var(--accent-amber)':'var(--accent-emerald)'};">
              ${m.correctionRate.toFixed(1)}%
            </span>
          </td>
          <td>${Utils.statusBadge(m.status)}</td>
          <td>
            <div style="display:flex;gap:6px;">
              <button class="btn btn-xs btn-secondary merchant-edit-btn" data-merchant-id="${m.id}" title="Edit"><i data-lucide="pencil" style="width:12px;"></i></button>
              <button class="btn btn-xs btn-ghost merchant-toggle-btn" data-merchant-id="${m.id}" title="${m.status==='active'?'Deactivate':'Activate'}" style="color:${m.status==='active'?'var(--accent-amber)':'var(--accent-emerald)'}"><i data-lucide="${m.status==='active'?'pause':'play'}" style="width:12px;"></i></button>
            </div>
          </td>
        </tr>`).join('');
    }

    document.getElementById('merchants-pagination-info').textContent = `Showing ${paged.length} of ${Merchants._filtered.length}`;
    document.getElementById('merchants-page-badge').textContent = `Page ${state.merchantsPage} of ${Utils.totalPages(Merchants._filtered, state.merchantsPageSize)}`;
    document.getElementById('merchants-prev-btn').disabled = state.merchantsPage <= 1;
    document.getElementById('merchants-next-btn').disabled = state.merchantsPage >= Utils.totalPages(Merchants._filtered, state.merchantsPageSize);

    refreshIcons();
    tbody.querySelectorAll('.merchant-edit-btn').forEach(btn=>btn.addEventListener('click', ()=>Merchants.openDrawer(btn.dataset.merchantId)));
    tbody.querySelectorAll('.merchant-toggle-btn').forEach(btn=>btn.addEventListener('click', async ()=>{
      const m = state.merchants.find(m=>m.id===btn.dataset.merchantId);
      if (m) {
        const nextStatus = m.status === 'active' ? 'inactive' : 'active';
        try {
          const res = await fetch(`${THEMAR_API_BASE}/statements/merchants/${m.id}/toggle`, {
            method: 'PATCH'
          });
          if (res.ok) {
            const data = await res.json();
            m.status = data.status || nextStatus;
            AuditLog.record('TOGGLE','Merchant',`${m.status==='active'?'Activated':'Deactivated'} merchant: ${m.name}`);
            Toast.success(`Merchant ${m.name} is now ${m.status}. Saved to themarip.db.`);
            Merchants._renderTable();
          } else {
            Toast.error('Failed to toggle merchant status in database.');
          }
        } catch (e) {
          m.status = nextStatus;
          AuditLog.record('TOGGLE','Merchant',`Toggled merchant: ${m.name}`);
          Toast.success(`Merchant ${m.status}.`);
          Merchants._renderTable();
        }
      }
    }));
  },

  openDrawer(merchantId) {
    const m = merchantId ? state.merchants.find(m=>m.id===merchantId) : null;
    document.getElementById('merchant-drawer-title').textContent = m ? 'Edit Merchant' : 'Add Merchant';
    document.getElementById('merchant-form-id').value = m?.id || '';
    document.getElementById('merchant-form-name').value = m?.name || '';
    document.getElementById('merchant-form-mcc').value = m?.mcc || '';
    document.getElementById('merchant-form-confidence').value = m?.defaultConfidence || 90;
    document.getElementById('merchant-form-status').value = m?.status || 'active';
    document.getElementById('merchant-form-aliases').value = m?.aliases.join('\n') || '';

    // Populate category select
    const catSel = document.getElementById('merchant-form-category');
    catSel.innerHTML = '<option value="">Select category…</option>';
    state.categories.filter(c=>c.enabled).forEach(c=>{
      const o = document.createElement('option');
      o.value = c.id;
      o.textContent = c.name;
      if (String(c.id).toLowerCase() === String(m?.defaultCategoryId || '').toLowerCase()) {
        o.selected = true;
      }
      catSel.appendChild(o);
    });

    catSel.onchange = ()=>Merchants._updateSubcatSelect(m?.defaultSubcategoryId||'');
    Merchants._updateSubcatSelect(m?.defaultSubcategoryId||'');

    Drawer.open('merchant-drawer');
  },

  _updateSubcatSelect(selectedSubId) {
    const catId = document.getElementById('merchant-form-category').value;
    const subSel = document.getElementById('merchant-form-subcategory');
    subSel.innerHTML = '<option value="">Select subcategory…</option>';
    Utils.getSubcatsForCategory(catId).filter(s=>s.enabled).forEach(s=>{
      const o = document.createElement('option');
      o.value = s.id;
      o.textContent = s.name;
      if (String(s.id).toLowerCase() === String(selectedSubId || '').toLowerCase()) {
        o.selected = true;
      }
      subSel.appendChild(o);
    });
  },

  async saveDrawer() {
    const id = document.getElementById('merchant-form-id').value;
    const name = document.getElementById('merchant-form-name').value.trim();
    const mcc = document.getElementById('merchant-form-mcc').value.trim();
    const categoryId = document.getElementById('merchant-form-category').value || null;
    const subcategoryId = document.getElementById('merchant-form-subcategory').value || null;
    const confidence = parseInt(document.getElementById('merchant-form-confidence').value)||90;
    const status = document.getElementById('merchant-form-status').value;
    const aliases = document.getElementById('merchant-form-aliases').value.split('\n').map(a=>a.trim()).filter(Boolean);

    if (!name) { Toast.error('Merchant name is required.'); return; }

    const payload = {
      name,
      mcc,
      defaultCategoryId: categoryId,
      defaultSubcategoryId: subcategoryId,
      defaultConfidence: confidence,
      status,
      aliases
    };

    try {
      if (id && id.length > 10 && !id.startsWith('m-')) {
        // Existing DB merchant (GUID)
        const res = await fetch(`${THEMAR_API_BASE}/statements/merchants/${id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (!res.ok) throw new Error('API save failed');
        
        const m = state.merchants.find(m=>m.id===id);
        if (m) {
          Object.assign(m, { name, mcc, defaultCategoryId:categoryId, defaultSubcategoryId:subcategoryId, defaultConfidence:confidence, status, aliases });
        }
        AuditLog.record('UPDATE','Merchant',`Updated merchant: ${name}`);
        Toast.success(`Merchant "${name}" updated and saved to themarip.db!`);
      } else {
        // New merchant or client-only mock
        const res = await fetch(THEMAR_API_BASE + '/statements/merchants', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (!res.ok) throw new Error('API create failed');
        const created = await res.json();
        const newId = created.id || ('m-' + Date.now());

        const newM = {
          id: newId,
          name,
          aliases,
          mcc,
          defaultCategoryId: categoryId,
          defaultSubcategoryId: subcategoryId,
          defaultConfidence: confidence,
          txCount: 0,
          correctionRate: 0,
          status
        };
        state.merchants.unshift(newM);
        AuditLog.record('CREATE','Merchant',`Created merchant: ${name}`);
        Toast.success(`Merchant "${name}" created and saved to themarip.db!`);
      }
    } catch (err) {
      console.error('Failed to save merchant to themarip.db:', err);
      // Fallback local memory update
      if (id) {
        const m = state.merchants.find(m=>m.id===id);
        if (m) Object.assign(m, { name, mcc, defaultCategoryId:categoryId, defaultSubcategoryId:subcategoryId, defaultConfidence:confidence, status, aliases });
      } else {
        state.merchants.unshift({ id:'m-'+Date.now(), name, aliases, mcc, defaultCategoryId:categoryId, defaultSubcategoryId:subcategoryId, defaultConfidence:confidence, txCount:0, correctionRate:0, status });
      }
      Toast.warning(`Saved locally (offline mode).`);
    }

    Drawer.close('merchant-drawer');
    Merchants.render();
    Nav.updateBadges();
  },

  initEvents() {
    document.getElementById('btn-add-merchant').addEventListener('click', ()=>Merchants.openDrawer(null));
    document.getElementById('merchant-drawer-save').addEventListener('click', Merchants.saveDrawer);
    document.getElementById('merchant-drawer-cancel').addEventListener('click', ()=>Drawer.close('merchant-drawer'));
    document.getElementById('merchant-drawer-close').addEventListener('click', ()=>Drawer.close('merchant-drawer'));
    document.getElementById('merchants-search').addEventListener('input', (e)=>{ state.merchantsSearch=e.target.value; state.merchantsPage=1; Merchants._applyFilters(); Merchants._renderTable(); });
    document.getElementById('merchants-filter-status').addEventListener('change', (e)=>{ state.merchantsFilterStatus=e.target.value; state.merchantsPage=1; Merchants._applyFilters(); Merchants._renderTable(); });
    document.getElementById('merchants-filter-category').addEventListener('change', (e)=>{ state.merchantsFilterCategory=e.target.value; state.merchantsPage=1; Merchants._applyFilters(); Merchants._renderTable(); });
    document.getElementById('merchants-prev-btn').addEventListener('click', ()=>{ if(state.merchantsPage>1){ state.merchantsPage--; Merchants._renderTable(); } });
    document.getElementById('merchants-next-btn').addEventListener('click', ()=>{ const tp=Utils.totalPages(Merchants._filtered,state.merchantsPageSize); if(state.merchantsPage<tp){ state.merchantsPage++; Merchants._renderTable(); } });
    document.getElementById('drawer-overlay').addEventListener('click', ()=>Drawer.closeAll());
  }
};

// ============================================================
// CONFIDENCE SETTINGS
// ============================================================
const ConfidenceSettings = {
  render() {
    const s = state.confidenceSettings;
    document.getElementById('band-high-min').value = s.bands.high.min;
    document.getElementById('band-high-max').value = s.bands.high.max;
    document.getElementById('band-high-action').value = s.bands.high.action;
    document.getElementById('band-med-min').value  = s.bands.medium.min;
    document.getElementById('band-med-max').value  = s.bands.medium.max;
    document.getElementById('band-med-action').value = s.bands.medium.action;
    document.getElementById('band-low-min').value  = s.bands.low.min;
    document.getElementById('band-low-max').value  = s.bands.low.max;
    document.getElementById('band-low-action').value = s.bands.low.action;
    document.getElementById('w-merchant').value  = s.weights.merchantMatch;
    document.getElementById('w-mcc').value       = s.weights.mccMatch;
    document.getElementById('w-narration').value = s.weights.narrationMatch;
    document.getElementById('w-historical').value= s.weights.historicalMatch;
    document.getElementById('w-amount').value    = s.weights.amountPattern;
    ConfidenceSettings._updateWeightVisual();
    ConfidenceSettings._updateWeightTotal();
  },

  _updateWeightVisual() {
    const w = [
      { key:'w-merchant',  color:'#3B82F6', label:'Merchant' },
      { key:'w-mcc',       color:'#8B5CF6', label:'MCC' },
      { key:'w-narration', color:'#06B6D4', label:'Narration' },
      { key:'w-historical',color:'#10B981', label:'Historical' },
      { key:'w-amount',    color:'#F97316', label:'Amount' },
    ];
    const values = w.map(x=>({ ...x, val:parseInt(document.getElementById(x.key)?.value||0) }));
    const total = values.reduce((s,x)=>s+x.val,0);
    const visual = document.getElementById('weight-visual');
    if (!visual) return;
    visual.innerHTML = `<div style="display:flex;height:20px;border-radius:6px;overflow:hidden;margin-bottom:16px;">
      ${values.map(x=>`<div style="width:${total>0?(x.val/total*100):0}%;background:${x.color};transition:width 0.3s;" title="${x.label}: ${x.val}%"></div>`).join('')}
    </div>
    <div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;">
      ${values.map(x=>`<div style="display:flex;align-items:center;gap:5px;font-size:11px;color:var(--text-muted);"><div style="width:8px;height:8px;border-radius:50%;background:${x.color};"></div>${x.label}</div>`).join('')}
    </div>`;
  },

  _updateWeightTotal() {
    const vals = ['w-merchant','w-mcc','w-narration','w-historical','w-amount'].map(id=>parseInt(document.getElementById(id)?.value||0));
    const total = vals.reduce((a,b)=>a+b,0);
    const el = document.getElementById('weight-total-display');
    if (el) { el.textContent = total + '%'; el.style.color = total===100 ? 'var(--accent-emerald)' : 'var(--accent-rose)'; }
  },

  save() {
    const vals = ['w-merchant','w-mcc','w-narration','w-historical','w-amount'].map(id=>parseInt(document.getElementById(id)?.value||0));
    const total = vals.reduce((a,b)=>a+b,0);
    if (total !== 100) { Toast.error(`Weights must total 100%. Currently: ${total}%`); return; }

    const prev = JSON.stringify(state.confidenceSettings);
    state.confidenceSettings = {
      weights: { merchantMatch:vals[0], mccMatch:vals[1], narrationMatch:vals[2], historicalMatch:vals[3], amountPattern:vals[4] },
      bands: {
        high:   { min:parseInt(document.getElementById('band-high-min').value), max:parseInt(document.getElementById('band-high-max').value), action:document.getElementById('band-high-action').value },
        medium: { min:parseInt(document.getElementById('band-med-min').value),  max:parseInt(document.getElementById('band-med-max').value),  action:document.getElementById('band-med-action').value },
        low:    { min:parseInt(document.getElementById('band-low-min').value),   max:parseInt(document.getElementById('band-low-max').value),   action:document.getElementById('band-low-action').value },
      }
    };
    AuditLog.record('UPDATE','ConfidenceSettings','Updated confidence thresholds and scoring weights');
    Toast.success('Confidence settings saved successfully.');
  },

  initEvents() {
    document.getElementById('btn-save-confidence').addEventListener('click', ConfidenceSettings.save);
    ['w-merchant','w-mcc','w-narration','w-historical','w-amount'].forEach(id=>{
      const el = document.getElementById(id);
      if (el) el.addEventListener('input', ()=>{ ConfidenceSettings._updateWeightVisual(); ConfidenceSettings._updateWeightTotal(); });
    });
  }
};

// ============================================================
// USER CORRECTIONS
// ============================================================
const Corrections = {
  _filtered: [],

  render() {
    Corrections._applyFilters();
    Corrections._renderTable();
    Corrections._renderSuggestions();
    Nav.updateBadges();
  },

  _applyFilters() {
    let corrs = [...state.corrections];
    if (state.correctionsSearch) { const s=state.correctionsSearch.toLowerCase(); corrs=corrs.filter(c=>c.merchantName.toLowerCase().includes(s)); }
    if (state.correctionsFilterStatus) corrs=corrs.filter(c=>c.status===state.correctionsFilterStatus);
    corrs.sort((a,b)=>new Date(b.date)-new Date(a.date));
    Corrections._filtered = corrs;
  },

  _renderTable() {
    const paged = Utils.paginate(Corrections._filtered, state.correctionsPage, state.correctionsPageSize);
    const tbody = document.getElementById('tbody-corrections');

    if (paged.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><p class="empty-state-title">No corrections found</p></div></td></tr>`;
    } else {
      tbody.innerHTML = paged.map(c=>`
        <tr>
          <td style="font-weight:500;">${c.merchantName}<br><span style="font-size:11px;color:var(--text-dim);">${c.narration}</span></td>
          <td>${Utils.getCategoryName(c.originalCategoryId)}<span style="color:var(--text-dim);font-size:12px;"> / ${Utils.getSubcategoryName(c.originalSubcategoryId)}</span></td>
          <td>${Utils.confidenceBadge(c.originalConfidence)}</td>
          <td><span style="font-weight:500;">${Utils.getCategoryName(c.correctedCategoryId)}</span><span style="color:var(--text-dim);font-size:12px;"> / ${Utils.getSubcategoryName(c.correctedSubcategoryId)}</span></td>
          <td style="font-size:12px;color:var(--text-muted);">${SEED.users.find(u=>u.id===c.userId)?.name||c.userId}</td>
          <td style="font-size:12px;color:var(--text-muted);">${Utils.fmt.date(c.date)}</td>
          <td>${Utils.statusBadge(c.status)}</td>
          <td>
            ${c.status==='pending' ? `<div style="display:flex;gap:5px;">
              <button class="btn btn-xs btn-success corr-approve-btn" data-corr-id="${c.id}" title="Approve">Approve</button>
              <button class="btn btn-xs btn-danger corr-reject-btn" data-corr-id="${c.id}" title="Reject">Reject</button>
            </div>` : `<span style="font-size:11px;color:var(--text-dim);">—</span>`}
          </td>
        </tr>`).join('');
    }

    document.getElementById('corrections-pagination-info').textContent = `Showing ${paged.length} of ${Corrections._filtered.length}`;
    document.getElementById('corrections-page-badge').textContent = `Page ${state.correctionsPage} of ${Utils.totalPages(Corrections._filtered, state.correctionsPageSize)}`;
    document.getElementById('corrections-prev-btn').disabled = state.correctionsPage <= 1;
    document.getElementById('corrections-next-btn').disabled = state.correctionsPage >= Utils.totalPages(Corrections._filtered, state.correctionsPageSize);

    refreshIcons();
    tbody.querySelectorAll('.corr-approve-btn').forEach(btn=>btn.addEventListener('click', ()=>Corrections.openApproveModal(btn.dataset.corrId)));
    tbody.querySelectorAll('.corr-reject-btn').forEach(btn=>btn.addEventListener('click', ()=>Corrections.rejectCorrection(btn.dataset.corrId)));
  },

  openApproveModal(corrId) {
    const corr = state.corrections.find(c=>c.id===corrId);
    if (!corr) return;
    const body = document.getElementById('correction-modal-body');
    body.innerHTML = `
      <div style="margin-bottom:16px;">
        <p style="font-size:13px;color:var(--text-muted);margin-bottom:12px;">User corrected <strong style="color:var(--text-main);">${corr.merchantName}</strong> from:</p>
        <div style="display:flex;align-items:center;gap:12px;padding:12px;background:rgba(255,255,255,0.04);border-radius:8px;margin-bottom:8px;">
          <span style="font-size:13px;color:var(--text-muted);">${Utils.getCategoryName(corr.originalCategoryId)} → ${Utils.getSubcategoryName(corr.originalSubcategoryId)}</span>
          <i data-lucide="arrow-right" style="width:14px;color:var(--accent-blue);"></i>
          <span style="font-size:13px;font-weight:600;">${Utils.getCategoryName(corr.correctedCategoryId)} → ${Utils.getSubcategoryName(corr.correctedSubcategoryId)}</span>
        </div>
      </div>
      <p style="font-size:13px;color:var(--text-muted);">How would you like to apply this correction?</p>`;

    const footer = document.getElementById('correction-modal-footer');
    footer.innerHTML = `
      <button class="btn btn-secondary" id="corr-modal-cancel">Cancel</button>
      <button class="btn btn-secondary" id="corr-apply-user" title="Apply only for this user">Apply to User Only</button>
      <button class="btn btn-primary" id="corr-global-rule" title="Create global rule for all users">Create Global Rule</button>`;

    document.getElementById('corr-modal-cancel').addEventListener('click', ()=>Modal.close('correction-modal-overlay'));
    document.getElementById('corr-apply-user').addEventListener('click', ()=>Corrections.applyToUser(corrId));
    document.getElementById('corr-global-rule').addEventListener('click', ()=>Corrections.createGlobalRule(corrId));

    Modal.open('correction-modal-overlay');
    refreshIcons();
  },

  applyToUser(corrId) {
    const corr = state.corrections.find(c=>c.id===corrId);
    if (!corr) return;
    corr.status = 'approved';
    AuditLog.record('APPROVE','Correction',`Applied user correction for ${corr.merchantName} to user ${corr.userId} only`);
    Toast.success('Correction applied to this user only.');
    Modal.close('correction-modal-overlay');
    Corrections.render();
  },

  createGlobalRule(corrId) {
    const corr = state.corrections.find(c=>c.id===corrId);
    if (!corr) return;
    corr.status = 'approved';
    // Create a new global rule
    const newRule = {
      id: 'rule-' + Date.now(),
      name: `${corr.merchantName} User Learning Rule`,
      conditions: [{ field:'merchant_name', operator:'contains', value:corr.merchantName, logic:'AND' }],
      categoryId: corr.correctedCategoryId,
      subcategoryId: corr.correctedSubcategoryId,
      confidence: 88,
      priority: 65,
      status: 'active',
      matchCount: 0,
    };
    state.rules.push(newRule);
    AuditLog.record('CREATE','Rule',`Created global rule from user correction: ${corr.merchantName} → ${Utils.getCategoryName(corr.correctedCategoryId)} / ${Utils.getSubcategoryName(corr.correctedSubcategoryId)}`);
    Toast.success('Global rule created from user correction.');
    Modal.close('correction-modal-overlay');
    Corrections.render();
    Nav.updateBadges();
  },

  async rejectCorrection(corrId) {
    const corr = state.corrections.find(c=>c.id===corrId);
    if (!corr) return;
    const ok = await Confirm.show('Reject Correction', `Reject the correction for "${corr.merchantName}"? The original categorization will be kept.`, 'Reject', true);
    if (ok) {
      corr.status = 'rejected';
      AuditLog.record('REJECT','Correction',`Rejected user correction for ${corr.merchantName}`);
      Toast.warning('Correction rejected.');
      Corrections.render();
    }
  },

  _renderSuggestions() {
    const grid = document.getElementById('suggested-rules-grid');
    const pending = state.suggestedRules.filter(s=>s.status==='pending');
    if (pending.length === 0) {
      grid.innerHTML = `<div class="empty-state" style="grid-column:1/-1;"><i data-lucide="check-circle-2" class="empty-state-icon" style="color:var(--accent-emerald);"></i><p class="empty-state-title">No pending rule suggestions</p><p class="empty-state-subtitle">The system will surface suggestions as repeated user corrections are detected.</p></div>`;
      refreshIcons();
      return;
    }
    grid.innerHTML = pending.map(s=>`
      <div class="suggested-rule-card">
        <div class="suggestion-header">
          <div style="display:flex;align-items:center;gap:8px;">
            <i data-lucide="lightbulb" style="color:var(--accent-amber);width:18px;"></i>
            <span style="font-weight:600;">${s.merchantName}</span>
          </div>
          <span class="badge badge-pending">${s.occurrences} occurrences</span>
        </div>
        <div class="suggestion-comparison">
          <div class="suggestion-side" style="border-color:var(--accent-rose);">
            <div style="font-size:10px;text-transform:uppercase;color:var(--text-muted);margin-bottom:4px;">Current</div>
            <div style="font-size:13px;">${Utils.getCategoryName(s.currentCategoryId)}<br><span style="color:var(--text-dim);">${Utils.getSubcategoryName(s.currentSubcategoryId)}</span></div>
          </div>
          <i data-lucide="arrow-right" style="width:16px;color:var(--accent-blue);margin:0 8px;"></i>
          <div class="suggestion-side" style="border-color:var(--accent-emerald);">
            <div style="font-size:10px;text-transform:uppercase;color:var(--text-muted);margin-bottom:4px;">Suggested</div>
            <div style="font-size:13px;font-weight:600;">${Utils.getCategoryName(s.suggestedCategoryId)}<br><span style="color:var(--accent-emerald);">${Utils.getSubcategoryName(s.suggestedSubcategoryId)}</span></div>
          </div>
        </div>
        <div style="margin-top:8px;font-size:12px;color:var(--text-muted);">Pattern: <code style="font-size:11px;color:var(--accent-cyan);">${s.pattern}</code></div>
        <div style="margin-top:4px;font-size:12px;color:var(--text-muted);">Suggested confidence: <strong>${s.suggestedConfidence}%</strong></div>
        <div style="display:flex;gap:8px;margin-top:12px;">
          <button class="btn btn-xs btn-primary sug-approve-btn" data-sug-id="${s.id}"><i data-lucide="check" style="width:12px;"></i> Approve Global Rule</button>
          <button class="btn btn-xs btn-danger sug-reject-btn" data-sug-id="${s.id}"><i data-lucide="x" style="width:12px;"></i> Reject</button>
        </div>
      </div>`).join('');
    refreshIcons();
    grid.querySelectorAll('.sug-approve-btn').forEach(btn=>btn.addEventListener('click', ()=>Corrections.approveSuggestion(btn.dataset.sugId)));
    grid.querySelectorAll('.sug-reject-btn').forEach(btn=>btn.addEventListener('click', ()=>Corrections.rejectSuggestion(btn.dataset.sugId)));
  },

  approveSuggestion(sugId) {
    const sug = state.suggestedRules.find(s=>s.id===sugId);
    if (!sug) return;
    sug.status = 'approved';
    const newRule = { id:'rule-'+Date.now(), name:`${sug.merchantName} — Learned Rule`, conditions:[{field:'narration',operator:'contains',value:sug.merchantName,logic:'AND'}], categoryId:sug.suggestedCategoryId, subcategoryId:sug.suggestedSubcategoryId, confidence:sug.suggestedConfidence, priority:70, status:'active', matchCount:0 };
    state.rules.push(newRule);
    AuditLog.record('APPROVE','SuggestedRule',`Approved global rule suggestion for ${sug.merchantName} → ${Utils.getCategoryName(sug.suggestedCategoryId)}`);
    Toast.success(`Global rule approved for ${sug.merchantName}.`);
    Corrections.render();
    Nav.updateBadges();
  },

  rejectSuggestion(sugId) {
    const sug = state.suggestedRules.find(s=>s.id===sugId);
    if (!sug) return;
    sug.status = 'rejected';
    AuditLog.record('REJECT','SuggestedRule',`Rejected rule suggestion for ${sug.merchantName}`);
    Toast.warning(`Suggestion rejected.`);
    Corrections.render();
    Nav.updateBadges();
  },

  initEvents() {
    document.querySelectorAll('.corrections-tab').forEach(tab=>{
      tab.addEventListener('click', ()=>{
        document.querySelectorAll('.corrections-tab').forEach(t=>t.classList.remove('active'));
        document.querySelectorAll('.corrections-tab-panel').forEach(p=>p.classList.add('hidden'));
        tab.classList.add('active');
        const target = tab.dataset.tab;
        const panel = document.getElementById(target);
        if (panel) panel.classList.remove('hidden');
        state.activeCorrectionsTab = target;
      });
    });
    document.getElementById('corrections-search').addEventListener('input', (e)=>{ state.correctionsSearch=e.target.value; state.correctionsPage=1; Corrections._applyFilters(); Corrections._renderTable(); });
    document.getElementById('corrections-filter-status').addEventListener('change', (e)=>{ state.correctionsFilterStatus=e.target.value; state.correctionsPage=1; Corrections._applyFilters(); Corrections._renderTable(); });
    document.getElementById('corrections-prev-btn').addEventListener('click', ()=>{ if(state.correctionsPage>1){ state.correctionsPage--; Corrections._renderTable(); } });
    document.getElementById('corrections-next-btn').addEventListener('click', ()=>{ const tp=Utils.totalPages(Corrections._filtered,state.correctionsPageSize); if(state.correctionsPage<tp){ state.correctionsPage++; Corrections._renderTable(); } });
    document.getElementById('correction-modal-close').addEventListener('click', ()=>Modal.close('correction-modal-overlay'));
  }
};

// ============================================================
// INTELLIGENCE RULES
// ============================================================
const Intelligence = {
  render() {
    const grid = document.getElementById('intelligence-rules-grid');
    grid.innerHTML = state.intelligenceRules.map(rule=>`
      <div class="intel-rule-card ${rule.status==='inactive'?'intel-rule-inactive':''}">
        <div class="intel-rule-header">
          <div style="display:flex;align-items:center;gap:10px;">
            <div style="width:36px;height:36px;border-radius:8px;background:${rule.iconColor}22;display:flex;align-items:center;justify-content:center;">
              <i data-lucide="${rule.icon}" style="width:18px;color:${rule.iconColor};"></i>
            </div>
            <div>
              <div style="font-weight:600;font-size:14px;">${rule.name}</div>
              <div style="font-size:11px;color:var(--text-dim);">${Intelligence._typeLabel(rule.type)}</div>
            </div>
          </div>
          <div style="display:flex;align-items:center;gap:8px;">
            <span class="badge ${rule.status==='active'?'badge-active':'badge-inactive'}" style="font-size:10px;">${rule.status}</span>
            <button class="btn btn-xs btn-ghost intel-toggle-btn" data-rule-id="${rule.id}" title="${rule.status==='active'?'Deactivate':'Activate'}">
              <i data-lucide="${rule.status==='active'?'pause-circle':'play-circle'}" style="width:14px;color:${rule.status==='active'?'var(--accent-amber)':'var(--accent-emerald)'};"></i>
            </button>
            <button class="btn btn-xs btn-ghost intel-edit-btn" data-rule-id="${rule.id}" title="Edit Parameters">
              <i data-lucide="settings-2" style="width:14px;"></i>
            </button>
          </div>
        </div>

        <div class="intel-insight-preview">"${Intelligence._renderPreview(rule)}"</div>

        <div class="intel-rule-params">
          ${Intelligence._renderParams(rule)}
        </div>

        <div class="intel-rule-stats">
          <div class="intel-stat"><i data-lucide="zap" style="width:12px;"></i> ${rule.fireCount} triggers</div>
          <div class="intel-stat"><i data-lucide="calendar" style="width:12px;"></i> Last: ${Utils.fmt.date(rule.lastFired)}</div>
        </div>
      </div>`).join('');
    refreshIcons();

    grid.querySelectorAll('.intel-toggle-btn').forEach(btn=>btn.addEventListener('click', ()=>Intelligence.toggle(btn.dataset.ruleId)));
    grid.querySelectorAll('.intel-edit-btn').forEach(btn=>btn.addEventListener('click', ()=>Intelligence.openModal(btn.dataset.ruleId)));
  },

  _typeLabel(type) {
    const labels = { high_spending:'High Spending Alert', unusual_spending:'Unusual Spending', low_balance:'Low Balance Alert', spending_increase:'Spending Increase', recurring:'Recurring Detection' };
    return labels[type] || type;
  },

  _renderPreview(rule) {
    let text = rule.insightTemplate;
    Object.entries(rule.params).forEach(([k,v])=>{ text=text.replace(new RegExp(`{${k}}`,'g'),`<strong>${v}</strong>`); });
    return text;
  },

  _renderParams(rule) {
    return Object.entries(rule.params).map(([k,v])=>`
      <div class="intel-param-chip">
        <span style="font-size:10px;color:var(--text-dim);text-transform:uppercase;">${k.replace(/_/g,' ')}</span>
        <span style="font-size:13px;font-weight:600;color:var(--text-main);">${v}</span>
      </div>`).join('');
  },

  toggle(ruleId) {
    const rule = state.intelligenceRules.find(r=>r.id===ruleId);
    if (!rule) return;
    rule.status = rule.status==='active' ? 'inactive' : 'active';
    AuditLog.record('TOGGLE','IntelligenceRule',`${rule.status==='active'?'Activated':'Deactivated'} intelligence rule: ${rule.name}`);
    Toast.success(`Intelligence rule "${rule.name}" ${rule.status}.`);
    Intelligence.render();
  },

  openModal(ruleId) {
    const rule = state.intelligenceRules.find(r=>r.id===ruleId);
    if (!rule) return;
    document.getElementById('intel-modal-title').textContent = `Edit: ${rule.name}`;

    const body = document.getElementById('intel-modal-body');
    body.innerHTML = `
      <input type="hidden" id="intel-form-rule-id" value="${rule.id}">
      <div class="form-group">
        <label class="form-label">Rule Name</label>
        <input type="text" id="intel-form-name" class="form-control" value="${rule.name}">
      </div>
      <div style="margin:16px 0 8px;font-size:13px;font-weight:600;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;">Parameters</div>
      <div id="intel-param-inputs">
        ${Object.entries(rule.params).map(([k,v])=>`
          <div class="form-group">
            <label class="form-label">${k.replace(/_/g,' ').replace(/\b\w/g,l=>l.toUpperCase())}</label>
            <input type="text" class="form-control intel-param-input" data-param-key="${k}" value="${v}">
          </div>`).join('')}
      </div>
      <div class="form-group">
        <label class="form-label">Insight Template</label>
        <textarea id="intel-form-template" class="form-control" rows="3">${rule.insightTemplate}</textarea>
        <p style="font-size:11px;color:var(--text-dim);margin-top:4px;">Use {paramName} placeholders matching the parameters above.</p>
      </div>
      <div class="form-group">
        <label class="form-label">Status</label>
        <select id="intel-form-status" class="form-control">
          <option value="active" ${rule.status==='active'?'selected':''}>Active</option>
          <option value="inactive" ${rule.status==='inactive'?'selected':''}>Inactive</option>
        </select>
      </div>`;

    Modal.open('intel-modal-overlay');
  },

  saveModal() {
    const ruleId = document.getElementById('intel-form-rule-id').value;
    const rule = state.intelligenceRules.find(r=>r.id===ruleId);
    if (!rule) return;

    rule.name = document.getElementById('intel-form-name').value.trim() || rule.name;
    rule.insightTemplate = document.getElementById('intel-form-template').value.trim() || rule.insightTemplate;
    rule.status = document.getElementById('intel-form-status').value;

    document.querySelectorAll('.intel-param-input').forEach(input=>{
      const key = input.dataset.paramKey;
      const val = input.value;
      const num = parseFloat(val);
      rule.params[key] = isNaN(num) ? val : num;
    });

    AuditLog.record('UPDATE','IntelligenceRule',`Updated intelligence rule: ${rule.name}`);
    Toast.success(`Intelligence rule "${rule.name}" updated.`);
    Modal.close('intel-modal-overlay');
    Intelligence.render();
  },

  initEvents() {
    document.getElementById('btn-add-intel-rule').addEventListener('click', ()=>{
      Toast.info('Select an existing rule to edit its parameters, or use the Edit button on any rule card.');
    });
    document.getElementById('intel-modal-save').addEventListener('click', Intelligence.saveModal);
    document.getElementById('intel-modal-cancel').addEventListener('click', ()=>Modal.close('intel-modal-overlay'));
    document.getElementById('intel-modal-close').addEventListener('click', ()=>Modal.close('intel-modal-overlay'));
  }
};

// ============================================================
// SETTINGS
// ============================================================
const Settings = {
  render() {
    AuditLog.render();
    // Load saved config
    const saved = JSON.parse(localStorage.getItem('themarip_config')||'{}');
    if (saved.clientId) document.getElementById('config-client-id').value = saved.clientId;
    if (saved.baseUrl) document.getElementById('config-base-url').value = saved.baseUrl;
    if (saved.clientCode) document.getElementById('config-client-code').value = saved.clientCode;
  },

  save() {
    const config = {
      clientId: document.getElementById('config-client-id').value,
      baseUrl: document.getElementById('config-base-url').value,
      clientCode: document.getElementById('config-client-code').value,
    };
    localStorage.setItem('themarip_config', JSON.stringify(config));
    AuditLog.record('UPDATE','Settings','Saved API configuration');
    Toast.success('Configuration saved.');
  },

  initEvents() {
    document.getElementById('btn-save-config').addEventListener('click', Settings.save);
  }
};

// ============================================================
// USER MANAGEMENT (CENTRAL CONTROL PLANE)
// ============================================================
const Users = {
  _users: [],

  async load() {
    try {
      const res = await fetch(THEMAR_API_BASE + '/statements/users');
      if (res.ok) {
        this._users = await res.json();
        const count = this._users.length;
        const badge = document.getElementById('nav-users-count');
        if (badge) badge.textContent = count;
        const kpi = document.getElementById('kpi-total-users');
        if (kpi) kpi.textContent = count;
        const trend = document.getElementById('kpi-users-trend');
        if (trend) {
          const admins = this._users.filter(u => (u.role || '').toLowerCase() === 'admin' || (u.email || '').toLowerCase() === 'admin@themar.ip').length;
          const regular = count - admins;
          trend.textContent = `${admins} Admin${admins === 1 ? '' : 's'}${regular > 0 ? `, ${regular} App User${regular === 1 ? '' : 's'}` : ' (Only Admin)'}`;
        }
      }
    } catch (e) {
      console.error('Failed to load users:', e);
    }
  },

  async render() {
    await this.load();
    const tbody = document.getElementById('users-table-body');
    if (!tbody) return;

    if (!this._users || this._users.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:24px;color:var(--text-muted);">No users found.</td></tr>';
      return;
    }

    tbody.innerHTML = this._users.map(u => {
      const isAdmin = (u.role || '').toLowerCase() === 'admin' || (u.email || '').toLowerCase() === 'admin@themar.ip';
      const isApproved = (u.accessStatus || '').toLowerCase() === 'approved';
      const isRejected = (u.accessStatus || '').toLowerCase() === 'rejected';
      const statusColor = isApproved ? 'var(--accent-emerald, #10B981)' : (isRejected ? 'var(--accent-rose, #F43F5E)' : 'var(--accent-amber, #F59E0B)');
      const dateStr = u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-GB') : '--';

      // 1. Bank Selection & Connected Statement formatting
      let banksHtml = '';
      if (u.banks && u.banks.length > 0) {
        banksHtml = u.banks.map(b => `
          <div style="margin:2px 0;">
            <span class="badge" style="background:rgba(16,185,129,0.12);color:#34D399;border:1px solid rgba(16,185,129,0.25);font-size:11px;font-weight:600;display:inline-flex;align-items:center;gap:4px;">
              <i data-lucide="landmark" style="width:11px;height:11px;"></i>
              ${b.name || b.code} <span style="opacity:0.75;font-weight:400;">(${b.txCount || 0} tx)</span>
            </span>
          </div>
        `).join('');
      } else if (u.connectedBanks && u.connectedBanks.length > 0) {
        banksHtml = u.connectedBanks.map(b => `
          <div style="margin:2px 0;">
            <span class="badge" style="background:rgba(16,185,129,0.12);color:#34D399;border:1px solid rgba(16,185,129,0.25);font-size:11px;font-weight:600;display:inline-flex;align-items:center;gap:4px;">
              <i data-lucide="landmark" style="width:11px;height:11px;"></i>
              ${b}
            </span>
          </div>
        `).join('');
      } else if (u.primaryBank || u.accountNumber) {
        const bankName = u.primaryBank || u.accountNumber;
        banksHtml = `
          <span class="badge" style="background:rgba(56,189,248,0.12);color:#38BDF8;border:1px solid rgba(56,189,248,0.25);font-size:11px;font-weight:600;display:inline-flex;align-items:center;gap:4px;">
            <i data-lucide="landmark" style="width:11px;height:11px;"></i>
            ${bankName}
          </span>
        `;
      } else {
        banksHtml = `<span style="color:var(--text-dim);font-size:11px;font-style:italic;">No bank linked</span>`;
      }

      // 2. Trust Score visual formatting
      const score = typeof u.trustScore === 'number' ? u.trustScore : 0;
      let scoreBadgeColor = '#94A3B8';
      let scoreBg = 'rgba(148,163,184,0.12)';
      if (score >= 80) { scoreBadgeColor = '#34D399'; scoreBg = 'rgba(16,185,129,0.15)'; }
      else if (score >= 50) { scoreBadgeColor = '#FBBF24'; scoreBg = 'rgba(245,158,11,0.15)'; }
      else if (score > 0) { scoreBadgeColor = '#F87171'; scoreBg = 'rgba(239,68,68,0.15)'; }

      return `
        <tr style="border-bottom:1px solid rgba(255,255,255,0.05);">
          <td style="padding:14px 16px;">
            <div style="display:flex;align-items:center;gap:10px;">
              <div style="width:32px;height:32px;border-radius:50%;background:${isAdmin ? 'rgba(16,185,129,0.2)' : 'rgba(124,58,237,0.15)'};color:${isAdmin ? '#10B981' : '#A78BFA'};display:flex;align-items:center;justify-content:center;font-weight:700;font-size:12px;">
                ${(u.fullName || u.email || 'U')[0].toUpperCase()}
              </div>
              <div>
                <div style="font-weight:600;color:var(--text-primary);font-size:13px;">${u.fullName || 'No Name'}</div>
                <div style="font-size:11px;color:var(--text-dim);">${u.id}</div>
              </div>
            </div>
          </td>
          <td style="padding:14px 16px;color:var(--text-muted);font-size:13px;">${u.email}</td>
          <td style="padding:14px 16px;">
            ${banksHtml}
          </td>
          <td style="padding:14px 16px;">
            <span class="badge" style="background:${isAdmin ? 'rgba(16,185,129,0.15)' : 'rgba(255,255,255,0.06)'};color:${isAdmin ? '#10B981' : 'inherit'};font-weight:${isAdmin ? '700' : '500'};font-size:11px;">
              ${u.role}
            </span>
          </td>
          <td style="padding:14px 16px;">
            <span class="badge" style="background:${statusColor}22;color:${statusColor};font-weight:600;font-size:11px;">
              ${u.accessStatus}
            </span>
          </td>
          <td style="padding:14px 16px;">
            <div class="open-user-profile-btn" data-user-id="${u.id}" style="display:inline-flex;align-items:center;gap:5px;cursor:pointer;" title="Click to view profile & adjust score">
              <span class="badge" style="background:${scoreBg};color:${scoreBadgeColor};font-weight:700;font-size:11.5px;padding:3px 8px;border:1px solid ${scoreBadgeColor}44;">
                <i data-lucide="shield" style="width:11px;height:11px;margin-right:2px;"></i>${score}
              </span>
            </div>
          </td>
          <td style="padding:14px 16px;color:var(--text-dim);font-size:12px;">${dateStr}</td>
          <td style="padding:14px 16px;text-align:right;">
            <div style="display:inline-flex;gap:6px;">
              <button class="btn btn-xs open-user-profile-btn" data-user-id="${u.id}" style="background:rgba(124,58,237,0.15);color:#A78BFA;border:1px solid rgba(124,58,237,0.3);" title="Profile & Score Management">
                <i data-lucide="user-cog" style="width:12px;height:12px;"></i> Manage
              </button>
              ${isAdmin ? `
                <span class="badge" style="background:rgba(16,185,129,0.12);color:#10B981;font-size:11px;padding:4px 8px;">Admin</span>
              ` : `
                <button class="btn btn-xs ${isApproved ? 'btn-secondary' : 'btn-primary'} toggle-user-status-btn" data-user-id="${u.id}" data-current-status="${u.accessStatus}">
                  ${isApproved ? 'Revoke' : 'Approve'}
                </button>
                <button class="btn btn-xs delete-user-btn" data-user-id="${u.id}" data-user-email="${u.email}" style="background:rgba(239,68,68,0.15);color:#F87171;border:1px solid rgba(239,68,68,0.3);">
                  <i data-lucide="trash-2"></i>
                </button>
              `}
            </div>
          </td>
        </tr>
      `;
    }).join('');

    refreshIcons();
    this.bindEvents();
  },

  openProfileModal(userId) {
    const user = this._users.find(u => u.id === userId);
    if (!user) return;
    this._activeEditingUserId = userId;

    const overlay = document.getElementById('user-profile-modal-overlay');
    if (!overlay) return;

    // Prefill info
    const avatar = document.getElementById('modal-user-avatar');
    if (avatar) avatar.textContent = (user.fullName || user.email || 'U')[0].toUpperCase();

    const nameEl = document.getElementById('modal-user-name');
    if (nameEl) nameEl.textContent = user.fullName || 'No Name';

    const emailEl = document.getElementById('modal-user-email');
    if (emailEl) emailEl.textContent = user.email || '';

    const metaEl = document.getElementById('modal-user-meta');
    if (metaEl) {
      const joined = user.createdAt ? new Date(user.createdAt).toLocaleDateString('en-GB') : '--';
      metaEl.textContent = `ID: ${user.id} • Joined: ${joined}`;
    }

    const isApproved = (user.accessStatus || '').toLowerCase() === 'approved';
    const isRejected = (user.accessStatus || '').toLowerCase() === 'rejected';
    const statusColor = isApproved ? 'var(--accent-emerald, #10B981)' : (isRejected ? 'var(--accent-rose, #F43F5E)' : 'var(--accent-amber, #F59E0B)');
    const statusPill = document.getElementById('modal-user-status-pill');
    if (statusPill) {
      statusPill.innerHTML = `<span class="badge" style="background:${statusColor}22;color:${statusColor};font-weight:700;font-size:11px;">${user.accessStatus}</span>`;
    }

    // Banks list
    const banksList = document.getElementById('modal-user-banks-list');
    const txCountEl = document.getElementById('modal-user-tx-count');
    if (banksList) {
      if (user.banks && user.banks.length > 0) {
        banksList.innerHTML = user.banks.map(b => `
          <div style="background:rgba(16,185,129,0.12);border:1px solid rgba(16,185,129,0.3);border-radius:8px;padding:6px 10px;display:flex;align-items:center;gap:6px;font-size:12px;color:#34D399;font-weight:600;">
            <i data-lucide="check-circle" style="width:13px;height:13px;"></i>
            ${b.name || b.code} &bull; ${b.txCount || 0} Transactions
          </div>
        `).join('');
        if (txCountEl) txCountEl.textContent = `${user.totalTransactions || 0} Total Transactions`;
      } else {
        banksList.innerHTML = `<span style="color:var(--text-dim);font-size:12px;font-style:italic;">No bank statements imported yet for this profile.</span>`;
        if (txCountEl) txCountEl.textContent = `0 txns`;
      }
    }

    // Primary bank selector
    const primaryBankSel = document.getElementById('modal-user-primary-bank');
    if (primaryBankSel) {
      primaryBankSel.value = user.primaryBank || user.accountNumber || (user.banks && user.banks[0] ? user.banks[0].name : '');
    }

    // Trust score slider & number
    const score = typeof user.trustScore === 'number' ? user.trustScore : 0;
    const slider = document.getElementById('modal-score-slider');
    const number = document.getElementById('modal-score-number');
    const display = document.getElementById('modal-score-display');
    if (slider) slider.value = score;
    if (number) number.value = score;
    if (display) {
      display.textContent = score;
      display.style.color = score >= 80 ? '#34D399' : (score >= 50 ? '#FBBF24' : '#F87171');
    }

    // Access Status & Role
    const statusSel = document.getElementById('modal-user-status');
    if (statusSel) statusSel.value = user.accessStatus || 'Pending';

    const roleSel = document.getElementById('modal-user-role');
    if (roleSel) roleSel.value = user.role || 'User';

    overlay.classList.remove('hidden');
    refreshIcons();
  },

  closeProfileModal() {
    const overlay = document.getElementById('user-profile-modal-overlay');
    if (overlay) overlay.classList.add('hidden');
    this._activeEditingUserId = null;
  },

  async saveProfile() {
    if (!this._activeEditingUserId) return;
    const userId = this._activeEditingUserId;

    const accessStatus = document.getElementById('modal-user-status')?.value || 'Pending';
    const role = document.getElementById('modal-user-role')?.value || 'User';
    const trustScore = parseInt(document.getElementById('modal-score-slider')?.value || '0', 10);
    const primaryBank = document.getElementById('modal-user-primary-bank')?.value || '';

    try {
      const res = await fetch(`${THEMAR_API_BASE}/statements/users/${userId}/profile`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          accessStatus,
          role,
          trustScore,
          primaryBank
        })
      });

      if (res.ok) {
        Toast.success('User profile & score updated successfully!');
        this.closeProfileModal();
        await Users.render();
      } else {
        const err = await res.text();
        Toast.error(err || 'Failed to update profile.');
      }
    } catch (e) {
      console.error(e);
      Toast.error('Network error updating user profile.');
    }
  },

  bindEvents() {
    // Open profile modal
    document.querySelectorAll('.open-user-profile-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const userId = btn.dataset.userId;
        if (userId) Users.openProfileModal(userId);
      });
    });

    // Toggle status button
    document.querySelectorAll('.toggle-user-status-btn').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const userId = btn.dataset.userId;
        const current = (btn.dataset.currentStatus || '').toLowerCase();
        const newStatus = (current === 'approved') ? 'Rejected' : 'Approved';
        try {
          const res = await fetch(`${THEMAR_API_BASE}/statements/users/${userId}/status`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: newStatus })
          });
          if (res.ok) {
            Toast.success(`User access updated to ${newStatus}.`);
            await Users.render();
          }
        } catch (e) {
          Toast.error('Failed to update status.');
        }
      });
    });

    // Delete user button
    document.querySelectorAll('.delete-user-btn').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const userId = btn.dataset.userId;
        const email = btn.dataset.userEmail;
        if (!confirm(`Are you sure you want to permanently delete user "${email}" and all associated data?`)) {
          return;
        }
        try {
          const res = await fetch(`${THEMAR_API_BASE}/statements/users/${userId}`, {
            method: 'DELETE'
          });
          if (res.ok) {
            Toast.success(`User "${email}" deleted successfully.`);
            await Users.render();
            Dashboard.render();
          } else {
            const err = await res.text();
            Toast.error(err || 'Failed to delete user.');
          }
        } catch (e) {
          Toast.error('Network error deleting user.');
        }
      });
    });
  },

  initEvents() {
    const refreshBtn = document.getElementById('btn-refresh-users');
    if (refreshBtn) refreshBtn.addEventListener('click', () => Users.render());

    // Modal close & cancel
    const closeBtn = document.getElementById('user-profile-modal-close');
    if (closeBtn) closeBtn.addEventListener('click', () => Users.closeProfileModal());

    const cancelBtn = document.getElementById('user-profile-cancel');
    if (cancelBtn) cancelBtn.addEventListener('click', () => Users.closeProfileModal());

    // Save profile
    const saveBtn = document.getElementById('user-profile-save');
    if (saveBtn) saveBtn.addEventListener('click', () => Users.saveProfile());

    // Sync score slider and number input
    const slider = document.getElementById('modal-score-slider');
    const number = document.getElementById('modal-score-number');
    const display = document.getElementById('modal-score-display');
    const updateScoreUi = (val) => {
      const v = Math.max(0, Math.min(100, parseInt(val || '0', 10)));
      if (slider) slider.value = v;
      if (number) number.value = v;
      if (display) {
        display.textContent = v;
        display.style.color = v >= 80 ? '#34D399' : (v >= 50 ? '#FBBF24' : '#F87171');
      }
    };
    if (slider) slider.addEventListener('input', (e) => updateScoreUi(e.target.value));
    if (number) number.addEventListener('input', (e) => updateScoreUi(e.target.value));

    // Preset buttons
    document.querySelectorAll('.btn-score-preset').forEach(btn => {
      btn.addEventListener('click', () => {
        const val = btn.dataset.score;
        updateScoreUi(val);
      });
    });

    // Close on overlay backdrop click
    const overlay = document.getElementById('user-profile-modal-overlay');
    if (overlay) {
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) Users.closeProfileModal();
      });
    }

    const purgeBtn = document.getElementById('btn-purge-users');
    if (purgeBtn) {
      purgeBtn.addEventListener('click', async () => {
        if (!confirm('Are you sure you want to delete ALL application users? Only the System Administrator (admin@themar.ip) will be kept.')) {
          return;
        }
        try {
          const res = await fetch(`${THEMAR_API_BASE}/statements/users/purge-non-admin`, {
            method: 'DELETE'
          });
          if (res.ok) {
            const data = await res.json();
            Toast.success(data.message || 'All non-admin users deleted.');
            await Users.render();
            Dashboard.render();
          } else {
            const err = await res.text();
            Toast.error(err || 'Failed to purge users.');
          }
        } catch (e) {
          Toast.error('Network error during purge.');
        }
      });
    }
  }
};

// ============================================================
// APP INIT
// ============================================================
const App = {
  init() {
    Nav.init();
    Transactions.initEvents();
    Categories.initEvents();
    Rules.initEvents();
    Merchants.initEvents();
    ConfidenceSettings.initEvents();
    Corrections.initEvents();
    Intelligence.initEvents();
    Users.initEvents();
    Settings.initEvents();
    App.initGlobalEvents();
    Users.load();
    Nav.updateBadges();
    Dashboard.render();
  },

  initGlobalEvents() {
    // Refresh button
    document.getElementById('btn-refresh').addEventListener('click', ()=>{
      const view = state.activeView;
      const renders = {
        'view-dashboard': Dashboard.render,
        'view-transactions': Transactions.render,
        'view-categories': Categories.render,
        'view-rules': Rules.render,
        'view-merchants': Merchants.render,
        'view-confidence': ConfidenceSettings.render,
        'view-corrections': Corrections.render,
        'view-intelligence': Intelligence.render,
        'view-users': Users.render,
        'view-settings': Settings.render,
      };
      if (renders[view]) renders[view]();
      Nav.updateBadges();
      Toast.info('Data refreshed.');
    });

    // Confirm dialog buttons
    document.getElementById('confirm-ok').addEventListener('click', ()=>Confirm.close(true));
    document.getElementById('confirm-cancel').addEventListener('click', ()=>Confirm.close(false));

    // Keyboard: Escape closes modals/drawers
    document.addEventListener('keydown', (e)=>{
      if (e.key === 'Escape') {
        Drawer.closeAll();
        document.querySelectorAll('.modal-overlay:not(.hidden)').forEach(m=>m.classList.add('hidden'));
      }
    });
  }
};

// ============================================================
// BOOTSTRAP
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  refreshIcons();
  Auth.init();
});
