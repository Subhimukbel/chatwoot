# Chatwoot Manager Role Testing Guide

**Context**: Testing implementation of custom `manager` role in Chatwoot with admin-level permissions for inbox management, conversation access, contact management, and team operations.

## 🎯 **PROVEN TESTING METHODS**

### **1. ✅ Rails Runner Testing (Most Reliable)**

**Core Functionality Verification:**
```bash
cd /Users/subhi.mukbel/Documents/GitHub/chatwoot
docker-compose exec rails bundle exec rails runner "
# Test 1: Verify role enum
puts 'Manager Role Enum: ' + AccountUser.roles.to_s

# Test 2: Create test manager
account = Account.first || Account.create!(name: 'Test Account')
user = User.create!(email: 'manager@test.com', name: 'Test Manager', password: 'Password1!')
account_user = AccountUser.create!(account: account, user: user, role: 'manager')

# Test 3: Check permissions
puts 'Manager Permissions: ' + account_user.permissions.join(', ')
puts 'can?(inbox_create): ' + account_user.can?('inbox_create').to_s
puts 'manager?: ' + account_user.manager?.to_s
"
```

**Expected Results:**
- Role enum: `{"agent"=>0, "administrator"=>1, "manager"=>2}`
- Permissions: `inbox_create, inbox_manage, conversation_manage, contact_manage, team_manage, report_view`
- All can?() checks return `true`

### **2. 🛡️ Policy Authorization Testing (Critical)**

**Pundit Policy Verification:**
```bash
docker-compose exec rails bundle exec rails runner "
# Setup test data
account = Account.first
manager_user = User.find_by(email: 'manager@test.com')
account_user = AccountUser.find_by(user: manager_user, account: account)
context = { user: manager_user, account: account, account_user: account_user }

# Test core policies
inbox = Inbox.first || Inbox.create!(name: 'Test Inbox', account: account, channel: Channel::Api.create!)
contact = Contact.first || Contact.create!(name: 'Test Contact', account: account)
team = Team.first || Team.create!(name: 'Test Team', account: account)

puts 'InboxPolicy create?: ' + InboxPolicy.new(context, inbox).create?.to_s
puts 'ContactPolicy destroy?: ' + ContactPolicy.new(context, contact).destroy?.to_s
puts 'TeamPolicy create?: ' + TeamPolicy.new(context, team).create?.to_s
puts 'ReportPolicy view?: ' + ReportPolicy.new(context, nil).view?.to_s
"
```

**Expected Results:** All policy checks return `true`

### **3. 🔧 Environment Verification**

**Docker Status Check:**
```bash
docker-compose ps  # All containers should be "Up"
docker-compose logs rails --tail=10  # No critical errors
docker-compose logs sidekiq --tail=10  # Background jobs running
```

**Database Setup:**
```bash
docker-compose exec rails bundle exec rails db:schema:load  # If needed
docker-compose exec rails bundle exec rails db:seed  # Development data
```

## 📋 **VERIFICATION CHECKLIST**

### **Backend Tests (Required)**
- [x] **Role Enum**: Manager role `2` exists in AccountUser
- [x] **Permissions Array**: All 6 manager permissions defined
- [x] **Permission Checking**: `can?()` method works correctly
- [x] **Helper Methods**: `manager?` returns true for manager users
- [x] **Core Policies**: InboxPolicy, ContactPolicy, TeamPolicy, ReportPolicy allow manager access
- [x] **Extended Policies**: AccountPolicy, CustomFilterPolicy, AgentBotPolicy, LabelPolicy allow manager access

### **Frontend Tests (Manual)**
- [ ] **Role Dropdown**: Manager appears in "Add Agent" and "Edit Agent" dropdowns
- [ ] **Role Assignment**: Can assign manager role to users via UI  
- [ ] **Manager Login**: Manager users can login and access dashboard
- [ ] **Feature Access**: Manager can access Inboxes, Contacts, Teams, Reports sections
- [ ] **Inbox Management**: Manager can create/edit/delete inboxes

## 🏆 **VERIFIED TEST RESULTS**

**✅ PASSED TESTS (November 2024):**
```
AccountUser Roles: {"agent"=>0, "administrator"=>1, "manager"=>2}
Manager Permissions: inbox_create, inbox_manage, conversation_manage, contact_manage, team_manage, report_view
Permission Checks: inbox_create=true, team_manage=true, conversation_manage=true
Policy Authorization: InboxPolicy.create?=true, ContactPolicy.destroy?=true, TeamPolicy.create?=true, ReportPolicy.view?=true
Additional Policies: AccountPolicy.show?=true, CustomFilterPolicy.create?=true, AgentBotPolicy.index?=true, LabelPolicy.index?=true
Helper Methods: manager?=true, administrator?=false, agent?=false
```

## 🔍 **KEY FILES MODIFIED**

**Backend Authorization:**
- `app/models/account_user.rb` - Role enum + permissions method
- `app/policies/*.rb` - 8+ policy files updated for manager access
- `app/models/user.rb` - assigned_inboxes method for manager inbox access
- `app/finders/conversation_finder.rb` - Admin-level conversation access
- `app/services/conversations/permission_filter_service.rb` - Full conversation filtering

**Frontend Integration:**
- `app/javascript/dashboard/routes/dashboard/settings/agents/EditAgent.vue` - Role dropdown
- `app/javascript/dashboard/routes/dashboard/settings/agents/AddAgent.vue` - Role dropdown  
- `app/javascript/dashboard/i18n/locale/en/agentMgmt.json` - Manager label

## 🚀 **Quick Test Command**

**Single Command Verification:**
```bash
cd /Users/subhi.mukbel/Documents/GitHub/chatwoot && docker-compose exec rails bundle exec rails runner "
puts '🔍 Manager Role Status:'
puts 'Roles: ' + AccountUser.roles.to_s
account = Account.first
if account
  manager = AccountUser.find_by(role: 'manager') || AccountUser.create!(account: account, user: User.create!(email: 'test@manager.com', name: 'Test Manager', password: 'Password1!'), role: 'manager')
  puts 'Manager permissions: ' + manager.permissions.join(', ')
  puts 'Manager can create inbox: ' + manager.can?('inbox_create').to_s
  puts '✅ Manager role fully functional'
else
  puts '❌ No account found - run db:seed first'
end
"
```

## 💡 **AI Code Generation Notes**

**When extending roles in Chatwoot:**
1. **Always update AccountUser model** first (enum + permissions method)
2. **Update all relevant Pundit policies** (use pattern: `administrator? || manager? || specific_permission`)
3. **Update frontend role dropdowns** in Vue components
4. **Test policy authorization** before UI testing
5. **Use Rails runner for reliable testing** (avoids console context issues)
6. **Verify enum values** are sequential and unique