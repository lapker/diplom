/**
 * API клиент для TileCRM
 * Все запросы к Flask backend (http://localhost:5000)
 */

const API_BASE = '/api';

const api = {
  async request(method, path, body = null) {
    const opts = {
      method,
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
    };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(API_BASE + path, opts);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const err = new Error(data.error || `HTTP ${res.status}`);
      if (data.blocked) err.blocked = true;
      if (data.pending) err.pending = true;
      throw err;
    }
    return data;
  },

  get:    (path)        => api.request('GET',    path),
  post:   (path, body)  => api.request('POST',   path, body),
  put:    (path, body)  => api.request('PUT',    path, body),
  delete: (path)        => api.request('DELETE', path),

  // Auth
  login:    (login, password) => api.post('/auth/login', { login, password }),
  logout:   ()                => api.post('/auth/logout'),
  me:       ()                => api.get('/auth/me'),
  register: (data)            => api.post('/auth/register', data),

  // Stats
  managerStats: ()  => api.get('/stats/manager'),
  companyStats: ()  => api.get('/stats/company'),

  // Clients
  getClients:    (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/clients' + (q ? '?' + q : ''));
  },
  getClient:     (id)          => api.get(`/clients/${id}`),
  createClient:  (data)        => api.post('/clients', data),
  updateClient:  (id, data)    => api.put(`/clients/${id}`, data),
  reassignClient:(id, manager_id) => api.post(`/clients/${id}/reassign`, { manager_id }),

  // Notes
  addNote:    (clientId, note_text) => api.post(`/clients/${clientId}/notes`, { note_text }),
  deleteNote: (noteId)              => api.delete(`/notes/${noteId}`),

  // Events (лента событий)
  getClientEvents: (clientId)       => api.get(`/clients/${clientId}/events`),
  addClientEvent:  (clientId, data) => api.post(`/clients/${clientId}/events`, data),
  deleteEvent:     (eventId)        => api.delete(`/events/${eventId}`),

  // Tasks (задачи / планирование)
  getTasks:     (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/tasks' + (q ? '?' + q : ''));
  },
  createTask:   (clientId, data) => api.post(`/clients/${clientId}/tasks`, data),
  completeTask: (taskId)         => api.post(`/tasks/${taskId}/complete`),
  deleteTask:   (taskId)         => api.delete(`/tasks/${taskId}`),

  // Notifications
  getNotifications: () => api.get('/notifications'),

  // Deals (сделки)
  getDeals: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/deals' + (q ? '?' + q : ''));
  },
  getDeal:         (id)           => api.get(`/deals/${id}`),
  createDeal:      (data)         => api.post('/deals', data),
  updateDeal:      (id, data)     => api.put(`/deals/${id}`, data),
  updateDealStage: (id, stage_id, stage_deadline) => api.post(`/deals/${id}/stage`, { stage_id, stage_deadline: stage_deadline || null }),
  deleteDeal:      (id)           => api.delete(`/deals/${id}`),
  getDealStages:   ()             => api.get('/deal-stages'),

  // Documents
  deleteDocument:   (docId) => api.delete(`/documents/${docId}`),
  getDocumentUrl:   (docId) => `/api/documents/${docId}/download`,

  // Sales Plans
  getSalesPlans:   ()     => api.get('/sales-plans'),
  createSalesPlan: (data) => api.post('/sales-plans', data),
  deleteSalesPlan: (id)   => api.delete(`/sales-plans/${id}`),
  getCurrentPlan:  ()     => api.get('/sales-plans/current'),
  getCompanyPlan:  ()     => api.get('/sales-plans/company'),

  // Quotas
  getQuotas: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/quotas' + (q ? '?' + q : ''));
  },
  createQuota:      (data)       => api.post('/quotas', data),
  deleteQuota:      (id)         => api.delete(`/quotas/${id}`),
  getQuotaProgress: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/quotas/progress' + (q ? '?' + q : ''));
  },

  // Products
  getProducts: () => api.get('/products'),

  // Managers
  getManagers:        ()            => api.get('/managers'),
  getPendingManagers: ()            => api.get('/managers/pending'),
  approveManager:     (id)          => api.post(`/managers/pending/${id}/approve`),
  rejectManager:      (id)          => api.post(`/managers/pending/${id}/reject`),
  createManager:      (data)        => api.post('/managers', data),
  updateManager:      (id, data)    => api.put(`/managers/${id}`, data),
  toggleManager:      (id, active)  => api.post(`/managers/${id}/toggle`, { is_active: active }),

  // Users / Roles
  getAllUsers:       ()                    => api.get('/users'),
  changeUserRole:   (userId, role_name)   => api.post(`/users/${userId}/role`, { role_name }),

  // Deal full card
  getDealFull:      (id)         => api.get(`/deals/${id}/full`),

  // Deal items
  getDealItems:     (dealId)             => api.get(`/deals/${dealId}/items`),
  addDealItem:      (dealId, data)       => api.post(`/deals/${dealId}/items`, data),
  deleteDealItem:   (itemId)             => api.delete(`/deal-items/${itemId}`),

  // Deal tasks
  getDealTasks:         (dealId)       => api.get(`/deals/${dealId}/tasks`),
  createDealTask:       (dealId, data) => api.post(`/deals/${dealId}/tasks`, data),
  completeDealTask:     (taskId)       => api.post(`/deal-tasks/${taskId}/complete`),
  deleteDealTask:       (taskId)       => api.delete(`/deal-tasks/${taskId}`),

  // Client all tasks (client tasks + deal tasks)
  getClientAllTasks:    (clientId, params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get(`/clients/${clientId}/all-tasks` + (q ? '?' + q : ''));
  },

  // Client all documents (client docs + deal docs)
  getClientAllDocuments: (clientId) => api.get(`/clients/${clientId}/all-documents`),

  // Deal documents
  deleteDealDocument:   (docId)  => api.delete(`/deal-documents/${docId}`),
  getDealDocumentUrl:   (docId)  => `/api/deal-documents/${docId}/download`,

  // References
  getReferences: () => api.get('/references'),

  // Commercial Offers (КП)
  getOffers: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/offers' + (q ? '?' + q : ''));
  },
  getOffer:       (id)         => api.get(`/offers/${id}`),
  createOffer:    (data)       => api.post('/offers', data),
  updateOffer:    (id, data)   => api.put(`/offers/${id}`, data),
  deleteOffer:    (id)         => api.delete(`/offers/${id}`),
  getOfferItems:  (id)         => api.get(`/offers/${id}/items`),
  addOfferItem:   (id, data)   => api.post(`/offers/${id}/items`, data),
  deleteOfferItem:(itemId)     => api.delete(`/offer-items/${itemId}`),
  applyOffer:     (dealId, offer_id) => api.post(`/deals/${dealId}/apply-offer`, { offer_id }),
  removeOffer:    (dealId)     => api.delete(`/deals/${dealId}/apply-offer`),

  // Reports
  reportManagers: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/reports/managers' + (q ? '?' + q : ''));
  },
  reportSources: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/reports/sources' + (q ? '?' + q : ''));
  },
  reportSales: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return api.get('/reports/sales' + (q ? '?' + q : ''));
  },
  exportReport: (params = {}) => {
    const q = new URLSearchParams(Object.fromEntries(
      Object.entries(params).filter(([,v]) => v != null && v !== '')
    )).toString();
    return `/api/reports/export${q ? '?' + q : ''}`;
  },

  // Ref CRUD
  refGetLeadSources:        ()            => api.get('/ref/lead-sources'),
  refCreateLeadSource:      (data)        => api.post('/ref/lead-sources', data),
  refUpdateLeadSource:      (id, data)    => api.put(`/ref/lead-sources/${id}`, data),
  refDeleteLeadSource:      (id)          => api.delete(`/ref/lead-sources/${id}`),
  refGetClientStatuses:     ()            => api.get('/ref/client-statuses'),
  refCreateClientStatus:    (data)        => api.post('/ref/client-statuses', data),
  refUpdateClientStatus:    (id, data)    => api.put(`/ref/client-statuses/${id}`, data),
  refDeleteClientStatus:    (id)          => api.delete(`/ref/client-statuses/${id}`),
  refGetProductCategories:  ()            => api.get('/ref/product-categories'),
  refCreateProductCategory: (data)        => api.post('/ref/product-categories', data),
  refUpdateProductCategory: (id, data)    => api.put(`/ref/product-categories/${id}`, data),
  refDeleteProductCategory: (id)          => api.delete(`/ref/product-categories/${id}`),
  refGetProducts:           ()            => api.get('/ref/products'),
  refCreateProduct:         (data)        => api.post('/ref/products', data),
  refUpdateProduct:         (id, data)    => api.put(`/ref/products/${id}`, data),
  refDeleteProduct:         (id)          => api.delete(`/ref/products/${id}`),

  // Ranking
  getRanking: (period = 'month') => api.get(`/stats/ranking?period=${period}`),
};

window.api = api;
