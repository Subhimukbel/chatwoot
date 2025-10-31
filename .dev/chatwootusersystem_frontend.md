# 🌐 Chatwoot Frontend User System Architecture Reference

> **Purpose**: Comprehensive guide for AI code generation and frontend authorization understanding
> **Scope**: Complete frontend user/role/permission patterns in Chatwoot Vue.js application
> **Last Updated**: November 2025

---

## 🎯 **EXECUTIVE SUMMARY**

**Architecture Type**: Dynamic permission-driven UI with centralized state management
**Primary Pattern**: Vuex store + Composables + Route-level authorization + Component policies
**Authorization Levels**: 4 distinct layers (Authentication → State → Component → Route)
**Key Components**: Auth store, usePolicy composable, policy component, route guards, permission helpers

---

## 📐 **CORE ARCHITECTURE PATTERNS**

### **Pattern 1: User Data Structure (Dynamic from Backend)**
```javascript
// Frontend receives this structure from backend /auth/validate_token
const currentUser = {
  id: 1,
  email: "user@example.com",
  name: "John Doe",
  account_id: 1,
  accounts: [
    {
      id: 1,
      name: "Acme Inc",
      role: "administrator",           // Built-in role: agent|administrator|manager
      custom_role_id: null,           // Enterprise custom role ID
      permissions: [                  // Dynamic permissions from backend
        "inbox_create",
        "conversation_manage", 
        "contact_manage",
        "team_manage"
      ],
      availability: "online",
      features: {                     // Account-level feature flags
        "custom_roles": true,
        "advanced_search": false
      }
    }
  ]
}
```

### **Pattern 2: Vuex State Management (Centralized)**
```javascript
// Location: app/javascript/dashboard/store/modules/auth.js
export const getters = {
  getCurrentUser: $state => $state.currentUser,
  getCurrentRole: ($state, $getters) => {
    const currentAccount = $state.currentUser.accounts.find(
      account => account.id === $getters.getCurrentAccountId
    );
    return currentAccount?.role;
  },
  getCurrentCustomRoleId: ($state, $getters) => {
    const currentAccount = $state.currentUser.accounts.find(
      account => account.id === $getters.getCurrentAccountId
    );
    return currentAccount?.custom_role_id;
  }
}

// Usage in components:
const currentRole = useMapGetter('getCurrentRole');
const currentUser = useMapGetter('getCurrentUser');
```

### **Pattern 3: Permission Helper System (Dynamic)**
```javascript
// Location: app/javascript/dashboard/helper/permissionsHelper.js
export const getUserPermissions = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  return currentAccount.permissions || [];  // Dynamic from backend
};

export const getUserRole = (user, accountId) => {
  const currentAccount = getCurrentAccount(user, accountId) || {};
  if (currentAccount.custom_role_id) {
    return 'custom_role';  // Enterprise custom role
  }
  return currentAccount.role || 'agent';  // Built-in role
};

export const hasPermissions = (requiredPermissions, availablePermissions) => {
  return requiredPermissions.some(permission =>
    availablePermissions.includes(permission)
  );
};
```

### **Pattern 4: usePolicy Composable (Component-Level)**
```javascript
// Location: app/javascript/dashboard/composables/usePolicy.js
export function usePolicy() {
  const user = useMapGetter('getCurrentUser');
  const { accountId } = useAccount();
  
  const getUserPermissionsForAccount = () => {
    return getUserPermissions(user.value, accountId.value);
  };
  
  const checkPermissions = requiredPermissions => {
    if (!requiredPermissions?.length) return true;
    const userPermissions = getUserPermissionsForAccount();
    return hasPermissions(requiredPermissions, userPermissions);
  };
  
  const shouldShow = (featureFlag, permissions, installationTypes) => {
    if (!checkPermissions(permissions)) return false;
    if (!checkInstallationType(installationTypes)) return false;
    return isFeatureFlagEnabled(featureFlag);
  };
  
  return { shouldShow, checkPermissions };
}
```

---

## 🔐 **AUTHENTICATION FLOW**

### **Layer 1: Session Management**
```javascript
// Location: app/javascript/dashboard/api/auth.js
export default {
  validityCheck() {
    return axios.get('/auth/validate_token');  // Gets user + accounts + permissions
  },
  hasAuthCookie() {
    return !!Cookies.get('cw_d_session_info');
  },
  getAuthData() {
    return JSON.parse(Cookies.get('cw_d_session_info') || '{}');
  }
}

// Location: app/javascript/dashboard/helper/APIHelper.js
if (Auth.hasAuthCookie()) {
  const { 'access-token': accessToken, client, uid } = Auth.getAuthData();
  Object.assign(wootApi.defaults.headers.common, {
    'access-token': accessToken,
    'token-type': 'Bearer',
    client,
    uid,
  });
}
```

### **Layer 2: Store Initialization**
```javascript
// Location: app/javascript/dashboard/store/modules/auth.js
export const actions = {
  async validityCheck(context) {
    const response = await authAPI.validityCheck();
    const currentUser = response.data.payload.data;  // Contains accounts with roles/permissions
    context.commit(types.SET_CURRENT_USER, currentUser);
  },
  
  async setUser({ commit, dispatch }) {
    if (authAPI.hasAuthCookie()) {
      await dispatch('validityCheck');  // Loads user data from backend
    }
  }
}
```

---

## 🎭 **ROLE & PERMISSION PATTERNS**

### **Built-in Roles (Hardcoded Constants)**
```javascript
// Location: app/javascript/dashboard/constants/permissions.js
export const ROLES = ['agent', 'administrator'];

// But frontend also supports 'manager' through dynamic backend data
// Role handling is mostly dynamic, not hardcoded
```

### **Permission-Based Authorization (Dynamic)**
```javascript
// Location: Various route files
const commonMeta = {
  permissions: ['administrator', 'agent', 'contact_manage'],  // Mixed: roles + permissions
};

// Location: app/javascript/dashboard/routes/dashboard/contacts/routes.js
export const routes = [
  {
    path: frontendURL('accounts/:accountId/contacts'),
    meta: commonMeta,  // Uses dynamic permission checking
    component: ContactsIndex,
  }
];
```

### **Custom Role Support (Enterprise)**
```javascript
// Location: app/javascript/dashboard/routes/dashboard/settings/agents/AddAgent.vue
const roles = computed(() => {
  const defaultRoles = [
    { id: 'administrator', name: 'administrator', label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR') },
    { id: 'manager', name: 'manager', label: t('AGENT_MGMT.AGENT_TYPES.MANAGER') },  // Added dynamically
    { id: 'agent', name: 'agent', label: t('AGENT_MGMT.AGENT_TYPES.AGENT') },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];  // Dynamic combination
});
```

---

## 🗂️ **COMPONENT AUTHORIZATION PATTERNS**

### **Pattern 1: Policy Component (Declarative)**
```vue
<!-- Location: app/javascript/dashboard/components/policy.vue -->
<template>
  <component :is="as" v-if="show">
    <slot />
  </component>
</template>

<script setup>
import { usePolicy } from 'dashboard/composables/usePolicy';

const props = defineProps({
  permissions: { type: Array, required: true },
  featureFlag: { type: String, default: null },
  installationTypes: { type: Array, default: null },
});

const { shouldShow } = usePolicy();
const show = computed(() =>
  shouldShow(props.featureFlag, props.permissions, props.installationTypes)
);
</script>

<!-- Usage in components: -->
<policy :permissions="['administrator', 'inbox_create']">
  <button @click="createInbox">Create Inbox</button>
</policy>
```

### **Pattern 2: Feature Flag Component**
```vue
<!-- Location: app/javascript/dashboard/components/widgets/FeatureToggle.vue -->
<template>
  <div v-if="isFeatureEnabled">
    <slot />
  </div>
</template>

<script>
export default {
  props: { featureKey: { type: String, required: true } },
  computed: {
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      accountId: 'getCurrentAccountId',
    }),
    isFeatureEnabled() {
      return this.isFeatureEnabledonAccount(this.accountId, this.featureKey);
    },
  },
}
</script>
```

### **Pattern 3: Composable-Based Checks**
```javascript
// Location: app/javascript/dashboard/composables/useAdmin.js
export function useAdmin() {
  const getters = useStoreGetters();
  
  const currentUserRole = computed(() => getters.getCurrentRole.value);
  const isAdmin = computed(() => currentUserRole.value === 'administrator');
  
  return { isAdmin };
}

// Usage in components:
const { isAdmin } = useAdmin();
```

---

## 🛣️ **ROUTE-LEVEL AUTHORIZATION**

### **Route Meta Permissions**
```javascript
// Location: app/javascript/dashboard/routes/dashboard/settings/settings.routes.js
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings'),
      meta: {
        permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],  // Dynamic permission array
      },
      redirect: to => {
        if (store.getters.getCurrentRole === 'administrator' &&    // Some hardcoded checks
            store.getters.getCurrentCustomRoleId === null) {
          return { name: 'general_settings_index', params: to.params };
        }
        return { name: 'canned_list', params: to.params };
      },
    }
  ]
}
```

### **Route Guard Implementation**
```javascript  
// Location: app/javascript/dashboard/routes/index.js
export const validateAuthenticateRoutePermission = (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return;
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

// Location: app/javascript/dashboard/components-next/sidebar/provider.js
const isAllowed = to => {
  const permissions = resolvePermissions(to);      // From route.meta.permissions
  const featureFlag = resolveFeatureFlag(to);     // From route.meta.featureFlag
  const installationType = resolveInstallationType(to);
  
  return shouldShow(featureFlag, permissions, installationType);
};
```

---

## 🎨 **CONDITIONAL RENDERING PATTERNS**

### **Permission-Based UI Filtering**
```javascript
// Location: app/javascript/dashboard/components/ChatList.vue
const userPermissions = computed(() => {
  return getUserPermissions(currentUser.value, currentAccountId.value);
});

const assigneeTabItems = computed(() => {
  return filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({
    key,
    name: t(`CHAT_LIST.ASSIGNEE_TYPE_TABS.${key}`),
    count: conversationStats.value[countKey] || 0,
  }));
});
```

### **Role-Based Conversation Filtering**
```javascript
// Location: app/javascript/dashboard/store/modules/conversations/helpers.js
export const applyRoleFilter = (conversation, role, permissions, currentUserId) => {
  if (['administrator', 'agent'].includes(role)) {
    return true;  // Some hardcoded role checks remain
  }
  
  if (permissions.includes('conversation_manage')) {
    return true;  // Dynamic permission check
  }
  
  // Additional permission-based logic...
  return false;
};

// Usage in store getters:
const getAllStatusChats = (_state, _, __, rootGetters) => activeFilters => {
  const currentUser = rootGetters.getCurrentUser;
  const permissions = getUserPermissions(currentUser, currentAccountId);
  const userRole = getUserRole(currentUser, currentAccountId);
  
  return _state.allConversations.filter(conversation => {
    return applyRoleFilter(conversation, userRole, permissions, currentUserId);
  });
};
```

---

## 📊 **FRONTEND AUTHORIZATION DISTRIBUTION**

### **CENTRALIZED COMPONENTS** ✅
| Component | Location | Purpose |
|-----------|----------|---------|
| **Auth Store** | `store/modules/auth.js` | User data, role, account management |
| **Permission Helpers** | `helper/permissionsHelper.js` | Dynamic permission checking |
| **usePolicy Composable** | `composables/usePolicy.js` | Component-level authorization |
| **Policy Component** | `components/policy.vue` | Declarative permission UI |
| **Route Guards** | `routes/index.js` | Route-level authorization |

### **MIXED PATTERNS** ⚠️
| Component | Pattern | Dynamic | Hardcoded |
|-----------|---------|---------|-----------|
| **Role Dropdowns** | Add/Edit Agent | ✅ Gets custom roles from store | ⚠️ Hardcoded default roles array |
| **Route Permissions** | Route meta | ✅ Permission arrays from backend | ⚠️ Some hardcoded role strings |
| **Conversation Filtering** | Store getters | ✅ Dynamic permission checking | ⚠️ Hardcoded admin/agent checks |
| **Command Bar** | useGoToCommandHotKeys | ✅ Feature flag checking | ⚠️ Hardcoded admin role filter |

---

## 🔧 **DATA FLOW ARCHITECTURE**

### **Authentication → Authorization Flow**
```
1. User Login
   ↓
2. Backend /auth/validate_token
   → Returns: user + accounts[] + role + permissions[] + features{}
   ↓
3. Frontend Auth Store
   → Vuex state: currentUser with dynamic account data
   ↓  
4. Permission Helpers
   → getUserPermissions() extracts current account permissions
   ↓
5. Component Authorization
   → usePolicy() / <policy> / route guards check permissions
   ↓
6. Conditional UI Rendering
   → v-if, route access, feature visibility
```

### **Role/Permission Resolution**
```
Frontend Role Logic:
if (currentAccount.custom_role_id) return 'custom_role'
else return currentAccount.role || 'agent'

Frontend Permission Logic:
return currentAccount.permissions || []  // Dynamic from backend

Frontend Authorization:
hasPermissions(requiredPermissions, userPermissions)
```

---

## 🎯 **AI CODE GENERATION GUIDELINES**

### **When Adding New Roles:**
1. **NO Frontend Role Constants**: Don't add to `ROLES` array - handled dynamically
2. **Update Role Dropdowns**: Add to `defaultRoles` in AddAgent.vue and EditAgent.vue
3. **Add I18n Labels**: Add role label to `agentMgmt.json`
4. **⚠️ Route Updates REQUIRED**: Must update route `meta.permissions` arrays for new roles (see Route Update Pattern below)
5. **No Store Updates**: Store gets role data from backend automatically

### **When Adding New Permissions:**
1. **Backend-First**: Define permissions in backend `AccountUser#permissions`
2. **Route Meta**: Add permission strings to route `meta.permissions` arrays (see Route Update Pattern)
3. **Component Policies**: Use `<policy :permissions="['new_permission']">`
4. **Permission Constants**: Add to `AVAILABLE_CUSTOM_ROLE_PERMISSIONS` if needed
5. **No Hardcoded Checks**: Avoid role-specific `if` statements

### **When Adding Protected UI:**
1. **Use Policy Component**: `<policy :permissions="[...]"><Button/></policy>`
2. **Use usePolicy Composable**: `const { shouldShow } = usePolicy()`
3. **Route-Level**: Add `meta: { permissions: [...] }` to routes (see Route Update Pattern)
4. **Feature Flags**: Use `<FeatureToggle featureKey="...">` for features
5. **Avoid Hardcoding**: Don't check roles directly, use permission arrays

### **Route Update Pattern (CRITICAL):**
```javascript
// ❌ BEFORE: Only administrator
meta: {
  permissions: ['administrator'],
}

// ✅ AFTER: Include both role AND permissions
meta: {
  permissions: ['administrator', 'team_manage'],  // Role + permission
}
```

**Route Update Checklist:**
1. **Find all routes** related to the feature (use `grep` to search route files)
2. **Identify permission** the new role should have (from backend `AccountUser#permissions`)
3. **Update route meta** - Add permission string to `meta.permissions` array
4. **Use `replace_all`** - Routes often have multiple instances (list, new, edit, show)
5. **Restart Vite** - Always restart frontend after route changes: `docker-compose restart vite`

**Example Route Update (Teams):**
```javascript
// File: app/javascript/dashboard/routes/dashboard/settings/teams/teams.routes.js
// BEFORE:
permissions: ['administrator'],

// AFTER (with replace_all):
permissions: ['administrator', 'team_manage'],
```

**Routes Updated for Manager Role:**
- ✅ **Inbox Routes** (6 routes) - Added `'inbox_create'` permission
- ✅ **Teams Routes** (7 routes) - Added `'team_manage'` permission
- ✅ **Profile Routes** (2 routes) - Added `'manager'` role
- ✅ **Reports Routes** (13+ routes) - Added `'report_view'` permission

**Common Route Patterns:**
- `settings/feature/list` - List view (usually has `['administrator']`)
- `settings/feature/new` - Create view (usually has `['administrator']`)
- `settings/feature/:id/edit` - Edit view (usually has `['administrator']`)
- `settings/feature/:id` - Show view (usually has `['administrator']`)

**Finding Routes to Update:**
```bash
# Find all routes with specific permission
grep -r "permissions.*administrator" app/javascript/dashboard/routes/dashboard/settings

# Find routes for specific feature
grep -r "inbox\|team\|report" app/javascript/dashboard/routes/dashboard/settings/*.routes.js
```

### **Best Practices:**
1. **Dynamic Over Static**: Prefer backend-driven permissions over hardcoded roles
2. **Permission Arrays**: Use string arrays, not role enums
3. **Composable Patterns**: Use `usePolicy()` over direct store access
4. **Declarative UI**: Use `<policy>` component over `v-if` with role checks
5. **Feature Flag Integration**: Combine permissions with feature flags for complete control
6. **Route Meta Updates**: Always update route permissions when adding new roles/permissions
7. **Use Replace All**: Routes often have multiple similar entries - use `replace_all: true`

---

## 🧩 **SYSTEM RELATIONSHIPS**

```
Backend API (/auth/validate_token)
    ↓
Frontend Auth Store (Vuex)
    ↓
Permission Helpers (Dynamic extraction)
    ↓
Authorization Composables (usePolicy, useAdmin)
    ↓
Component-Level Authorization (<policy>, v-if)
    ↓
Route-Level Guards (meta.permissions)
    ↓
Conditional UI Rendering
```

**Key Integration Points:**
- **Backend-driven permissions** flow into all frontend authorization layers
- **Vuex store** provides centralized user/account/role state
- **Dynamic permission checking** supersedes hardcoded role logic
- **Composables** provide reusable authorization logic
- **Route guards** enforce page-level access control
- **Component policies** enable granular UI authorization

---

## 🔍 **FRONTEND vs BACKEND DIFFERENCES**

### **Frontend Characteristics:**
- ✅ **Dynamic permission fetching** from backend via API
- ✅ **Reactive UI updates** when permissions change  
- ✅ **Multi-account support** with per-account roles/permissions
- ✅ **Feature flag integration** for installation-specific features
- ⚠️ **Mixed patterns** - some hardcoded role checks remain
- ⚠️ **Role dropdown hardcoding** - default roles statically defined

### **Backend Characteristics (for comparison):**
- ✅ **Centralized permission logic** in AccountUser model
- ✅ **Policy-based authorization** via Pundit
- ✅ **Database-driven roles** with enum definitions
- ✅ **Service-layer filtering** based on roles/permissions

**Frontend correctly gets most data dynamically from backend, but has some legacy hardcoded patterns that should be migrated to dynamic permission checking.**
