# 🏗️ Chatwoot Authorization Architecture Reference

> **Purpose**: Comprehensive guide for AI code generation and system understanding
> **Scope**: Complete authorization patterns in Chatwoot backend
> **Last Updated**: November 2025

---

## 🎯 **EXECUTIVE SUMMARY**

**Architecture Type**: Multi-layered RBAC with partial ABAC support
**Primary Pattern**: Pundit policies + AccountUser permissions + Multi-tenancy
**Authorization Levels**: 6 distinct layers (Authentication → Account → Role → Resource → Feature → External)
**Total Components**: 22 policies, 29+ controllers, 15+ services, 14+ models

---

## 📐 **CORE ARCHITECTURE PATTERNS**

### **Pattern 1: Thread-Local Context Management**
```ruby
# Location: lib/current.rb
module Current
  thread_mattr_accessor :user        # Authenticated user object
  thread_mattr_accessor :account     # Active tenant/account  
  thread_mattr_accessor :account_user # User-account relationship + role
end

# Usage throughout codebase:
Current.user.id
Current.account.inboxes
Current.account_user.administrator?
```

### **Pattern 2: AccountUser Permission System**
```ruby
# Location: app/models/account_user.rb - CENTRAL PERMISSION SOURCE
class AccountUser < ApplicationRecord
  enum role: { agent: 0, administrator: 1, manager: 2 }
  
  def permissions
    case role
    when 'administrator' then ['administrator']
    when 'manager' then ['inbox_create', 'inbox_manage', 'conversation_manage', ...]
    else ['agent']
    end
  end
  
  def can?(permission)
    permissions.include?(permission) || permissions.include?('administrator')
  end
end
```

### **Pattern 3: Pundit Policy Authorization**
```ruby
# Location: app/policies/*.rb (22 policy files)
class InboxPolicy < ApplicationPolicy
  def create?
    @account_user.administrator? || @account_user.can?('inbox_create')
  end
  
  def update? 
    @account_user.administrator? || @account_user.can?('inbox_manage')
  end
end

# Controller usage:
authorize @inbox, :create?  # Calls InboxPolicy#create?
```

### **Pattern 4: Multi-Tenant Access Control**
```ruby
# Location: app/controllers/concerns/ensure_current_account_helper.rb
def account_accessible_for_user?(account)
  @current_account_user = account.account_users.find_by(user_id: current_user.id)
  Current.account_user = @current_account_user
  render_unauthorized unless @current_account_user
end
```

---

## 🔐 **AUTHENTICATION LAYERS** 

### **Layer 1: Multi-Level Authentication**
```ruby
# A. Regular Users (DeviseTokenAuth + Access Tokens)
class Api::BaseController
  before_action :authenticate_access_token!, if: :authenticate_by_access_token?
  before_action :authenticate_user!, unless: :authenticate_by_access_token?
end

# B. Super Admins (System-wide)  
class SuperAdmin::ApplicationController
  before_action :authenticate_super_admin!  # Full system access
end

# C. Platform Apps (External integrations)
class PlatformController
  before_action :set_platform_app
  before_action :validate_platform_app_permissible  # Resource-specific access
end

# D. Agent Bots (Limited API access)
BOT_ACCESSIBLE_ENDPOINTS = {
  'api/v1/accounts/conversations' => %w[toggle_status create update],
  'api/v1/accounts/conversations/messages' => ['create']
}.freeze
```

### **Layer 2: Token Types & Scopes**
- **Access Token**: `api_access_token` header → User/AgentBot access
- **DeviseToken**: `access-token`, `client`, `uid` → Session-based
- **Widget Token**: Website visitor authentication
- **Webhook Tokens**: Per-integration verification (WhatsApp, Instagram, etc.)

---

## 🏢 **MULTI-TENANCY ARCHITECTURE**

### **Core Tenant Model**
```ruby
# Database schema pattern:
accounts (tenants)
├── users (global user pool)
└── account_users (pivot: user ↔ account + role)
    ├── user_id, account_id, role
    ├── custom_role_id (enterprise)
    └── availability, inviter_id

# Access control pattern:
User.assigned_inboxes  # Based on role + inbox_members
Account.administrators # Scoped by account_id + role
Account.agents        # Scoped by account_id + role  
```

### **Resource Scoping Patterns**
```ruby
# All resources are account-scoped:
@account.conversations.where(...)
@account.inboxes.includes(...)
@account.users.where(account_users: { role: :administrator })

# Service filtering:
Conversations::PermissionFilterService.new(conversations, user, account).perform
```

---

## 🎭 **ROLE-BASED ACCESS CONTROL (RBAC)**

### **Built-in Roles**
```ruby
enum role: { 
  agent: 0,         # Limited access - assigned inboxes only
  administrator: 1, # Full account access
  manager: 2        # Extended access - can create/manage inboxes
}
```

### **Permission Mapping**
| Role | Permissions | Inbox Access | Conversation Access |
|------|-------------|--------------|-------------------|
| `agent` | `['agent']` | Assigned only (`inbox_members`) | Assigned inbox conversations |
| `administrator` | `['administrator']` | All account inboxes | All account conversations |
| `manager` | `['inbox_create', 'inbox_manage', 'conversation_manage', ...]` | All account inboxes | All account conversations |

### **Authorization Check Patterns**
```ruby
# Pattern A: Direct role checks (DISTRIBUTED - needs updates)
@account_user.administrator?
@current_account_user.agent?
user_role == 'administrator'

# Pattern B: Permission-based (CENTRALIZED - preferred)  
@account_user.can?('inbox_create')
@account_user.can?('conversation_manage')

# Pattern C: Policy-based (CENTRALIZED - Pundit)
authorize @inbox, :create?
policy_scope(Account.inboxes)
```

---

## 🏛️ **POLICY ARCHITECTURE (22 FILES)**

### **Policy Inheritance**
```ruby
class ApplicationPolicy
  def initialize(user_context, record)
    @user = user_context[:user]
    @account = user_context[:account] 
    @account_user = user_context[:account_user]
    @record = record
  end
end

# All policies inherit common patterns:
class InboxPolicy < ApplicationPolicy
class ContactPolicy < ApplicationPolicy  
class ConversationPolicy < ApplicationPolicy
# ... 19 more policies
```

### **Policy Scope Pattern**
```ruby
class InboxPolicy::Scope
  def resolve
    user.assigned_inboxes  # Delegates to User model logic
  end
end

# Controller usage:
@inboxes = policy_scope(Current.account.inboxes)
```

---

## 🔍 **RESOURCE ACCESS PATTERNS**

### **Inbox-Based Access Control**
```ruby
# Location: app/models/user.rb
def assigned_inboxes
  administrator? ? Current.account.inboxes : inboxes.where(account_id: Current.account.id)
end

# Usage in services:
class ConversationFinder
  def set_inboxes
    @inbox_ids = @current_user.assigned_inboxes.pluck(:id)
  end
end
```

### **Conversation Filtering Service**
```ruby  
# Location: app/services/conversations/permission_filter_service.rb
class Conversations::PermissionFilterService
  def perform
    return conversations if user_role == 'administrator'
    accessible_conversations  # Filters by assigned inboxes
  end
end

# Enterprise Extension:
module Enterprise::Conversations::PermissionFilterService
  def perform
    return filter_by_permissions(permissions) if user_has_custom_role?
    super
  end
end
```

---

## 🎚️ **FEATURE FLAG SYSTEM**

### **Feature-Based Authorization**
```ruby
# Location: app/models/concerns/featurable.rb
class Account
  include Featurable
  
  def feature_enabled?(name)
    send("feature_#{name}?")  # Uses FlagShihTzu binary flags
  end
end

# Usage patterns:
account.feature_enabled?('advanced_search')
account.feature_enabled?('crm_integration') 
ChatwootApp.enterprise?  # Enterprise feature gating
```

### **Premium Feature Control**
```yaml
# config/features.yml
- name: disable_branding
  display_name: Disable Branding  
  enabled: false
  premium: true  # Requires paid plan

- name: advanced_search
  display_name: Advanced Search
  enabled: false
  premium: true
```

---

## 🏢 **ENTERPRISE VS CORE DIFFERENCES**

### **Core (MIT License)**
- **Roles**: `agent`, `administrator` (built-in)
- **Permissions**: Simple array from `AccountUser#permissions`
- **Policies**: Direct role checks in Pundit policies
- **Licensing**: Open source, unrestricted modification

### **Enterprise (Proprietary License)** 
- **Custom Roles**: `CustomRole` model with flexible permissions
- **Permission Override**: `Enterprise::AccountUser#permissions` 
- **Advanced Filtering**: Permission-based conversation filtering
- **Licensing**: Requires subscription for production use

```ruby
# Enterprise custom role example:
class CustomRole < ApplicationRecord
  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage  
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
  ].freeze
end

# Enterprise AccountUser override:
module Enterprise::AccountUser
  def permissions
    custom_role.present? ? (custom_role.permissions + ['custom_role']) : super
  end
end
```

---

## 📊 **AUTHORIZATION DISTRIBUTION MAP**

### **CENTRALIZED COMPONENTS** ✅
| Component | Location | Purpose |
|-----------|----------|---------|
| Context Management | `lib/current.rb` | Thread-local state |
| Permission System | `AccountUser#permissions` | Role → Permission mapping |
| Policy Framework | `app/policies/*.rb` | Pundit authorization |
| Feature Flags | `Featurable` concern | Feature-based access |

### **DISTRIBUTED COMPONENTS** ⚠️ 
| Component | Files | Pattern | Issue |
|-----------|-------|---------|-------|
| Direct Role Checks | 20+ controllers/services | `administrator?` | Hard-coded admin logic |
| Inbox Access | `User#assigned_inboxes` | Role-based filtering | Needs manager support |
| Conversation Filtering | `ConversationFinder`, `PermissionFilterService` | Admin vs others | Manager missing |
| Account Scopes | `Account` model | `.administrators`, `.agents` | No manager inclusion |

---

## 🔧 **EXTENSION PATTERNS**

### **Model Extensions (prepend_mod_with)**
```ruby
# Core model can be extended by enterprise modules:
AccountUser.prepend_mod_with('AccountUser')           # Enterprise::AccountUser
AccountUser.include_mod_with('Audit::AccountUser')   # Audit logging
AccountUser.include_mod_with('Concerns::AccountUser') # Additional concerns
```

### **Service Extensions**
```ruby
# Services can be extended with enterprise functionality:
Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
ConversationFinder.prepend_mod_with('ConversationFinder')
```

---

## 🎯 **AI CODE GENERATION GUIDELINES**

### **When Adding New Roles:**
1. **Update AccountUser enum**: Add role to enum definition
2. **Update permissions method**: Define role-specific permissions array  
3. **Update policies**: Use `can?()` method instead of direct role checks
4. **Update distributed logic**: Search for `administrator?` checks in finders/services
5. **Update model scopes**: Include new role in relevant account scopes
6. **Test authorization**: Verify access patterns match intended permissions

### **When Adding New Policies:**
1. **Inherit from ApplicationPolicy**: Use standard user_context pattern
2. **Define policy scope**: Control record filtering via `resolve` method
3. **Use permission checks**: Prefer `@account_user.can?('permission')` 
4. **Add controller authorization**: Use `authorize(model)` in controllers
5. **Handle enterprise**: Consider if enterprise extensions needed

### **When Adding New Features:**
1. **Add to features.yml**: Define feature with appropriate flags
2. **Use feature_enabled?**: Check `account.feature_enabled?('feature_name')`
3. **Consider premium**: Mark `premium: true` if paid feature
4. **Update policies**: Add feature checks to relevant policies
5. **Test feature flags**: Verify enabled/disabled behavior

---

## 🧩 **SYSTEM RELATIONSHIPS**

```
Authentication Layer
    ↓
Account Access Layer (Multi-tenancy)
    ↓  
Role-Based Authorization (AccountUser + Policies)
    ↓
Resource Access Control (Inbox membership, Team membership)
    ↓
Feature Authorization (Feature flags, Enterprise gating)
    ↓
External Security (Webhooks, Platform apps, Widgets)
```

**Key Integration Points:**
- **Current context** flows through all layers
- **AccountUser permissions** drive policy decisions  
- **Pundit policies** provide centralized authorization
- **Service filtering** enforces resource access
- **Feature flags** gate functionality availability
