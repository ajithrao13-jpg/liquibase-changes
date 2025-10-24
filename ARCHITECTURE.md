# Architecture Documentation - S-Docs Deployment Automation

## 🏗️ System Architecture

This document explains how all the components work together to automate S-Docs template deployment.

---

## 📊 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Developer/CI/CD                         │
└────────────┬────────────────────────────────────────────────┘
             │
             │ Triggers deployment
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Entry Points                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ npm scripts  │  │ GitHub       │  │ Manual          │  │
│  │ (local)      │  │ Actions      │  │ execution       │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘  │
└─────────┼──────────────────┼───────────────────┼───────────┘
          │                  │                   │
          └──────────────────┴───────────────────┘
                             │
                             ▼
          ┌──────────────────────────────────────┐
          │   scripts/sdocs-upserter.js          │
          │                                      │
          │  1. Verify SF connection             │
          │  2. Read template files              │
          │  3. Validate templates               │
          │  4. Upsert to Salesforce            │
          │  5. Report results                   │
          └──────────┬───────────────────────────┘
                     │
                     ▼
          ┌──────────────────────────────────────┐
          │   data/sdocsTemplates/               │
          │   (Template JSON files)              │
          └──────────┬───────────────────────────┘
                     │
                     ▼
          ┌──────────────────────────────────────┐
          │   Salesforce Org                     │
          │   (S-Docs Package)                   │
          └──────────────────────────────────────┘
```

---

## 🔄 Workflow Integrations

### 1. Local Development Workflow

```
Developer
    │
    ├─→ git clone repository
    │
    ├─→ npm install
    │
    ├─→ sf org login web
    │
    └─→ npm run setup:dev:local
        │
        ├─→ npm run setup:dev:base
        │   └─→ Run base setup tasks
        │
        └─→ npm run sdocs:upsertAll
            └─→ Deploy S-Docs templates
```

### 2. CI/CD Deployment Workflow

```
Code Push (main/develop)
    │
    ▼
GitHub Actions Trigger
    │
    ├─→ Checkout code
    ├─→ Setup Node.js
    ├─→ Install dependencies
    ├─→ Install Salesforce CLI
    ├─→ Authenticate to Salesforce
    ├─→ Deploy metadata
    │
    └─→ Deploy S-Docs Templates ✨
        │
        └─→ npm run sdocs:upsertAll
            │
            └─→ Success/Failure notification
```

### 3. Scratch Org Creation Workflow

```
Pull Request Created
    │
    ▼
GitHub Actions Trigger
    │
    ├─→ Authenticate to DevHub
    ├─→ Create scratch org
    ├─→ Deploy source code
    │
    └─→ Setup scratch org with S-Docs ✨
        │
        ├─→ npm run setup:dev:ci
        │   │
        │   └─→ npm run sdocs:upsertAll
        │
        ├─→ Assign permission sets
        └─→ Import sample data
```

### 4. Post-Refresh Workflow

```
Sandbox Refresh Complete
    │
    ▼
DevOps Engineer
    │
    ├─→ sf org login web --alias refreshed-sandbox
    │
    └─→ npm run setup:dev:lowerSandbox
        │
        ├─→ npm run setup:dev:base
        │   └─→ Base configuration
        │
        └─→ npm run sdocs:upsertAll ✨
            └─→ Restore S-Docs templates
```

---

## 🔌 Component Interactions

### Package.json Scripts

```javascript
{
  "sdocs:upsertAll": "node scripts/sdocs-upserter.js",
  // ↑ Core command that runs the upserter script
  
  "setup:dev:local": "npm run setup:dev:base && npm run sdocs:upsertAll",
  // ↑ Chains base setup + S-Docs deployment
  
  "setup:dev:ci": "npm run setup:dev:base && npm run sdocs:upsertAll",
  // ↑ CI-specific setup + S-Docs deployment
  
  "setup:dev:lowerSandbox": "npm run setup:dev:base && npm run sdocs:upsertAll",
  // ↑ Lower sandbox setup + S-Docs deployment
  
  "setup:dev:higherSandbox": "npm run setup:dev:base && npm run sdocs:upsertAll"
  // ↑ Higher sandbox setup + S-Docs deployment
}
```

**Key Points:**
- All setup scripts include S-Docs deployment
- Uses `&&` operator for sequential execution
- Failure in any step prevents subsequent steps

### S-Docs Upserter Script Flow

```
main()
  │
  ├─→ getConnectedOrg()
  │   │
  │   ├─→ Try: sf org display --json
  │   │   └─→ Return username
  │   │
  │   └─→ Catch: Try sfdx force:org:display --json
  │       └─→ Return username or throw error
  │
  ├─→ getTemplateFiles()
  │   │
  │   ├─→ Check if data/sdocsTemplates exists
  │   ├─→ Read directory contents
  │   ├─→ Filter for .json files
  │   └─→ Return array of file paths
  │
  └─→ For each template file:
      │
      └─→ upsertTemplate(file)
          │
          ├─→ Read and parse JSON
          ├─→ Validate structure
          ├─→ Upsert to Salesforce API
          └─→ Return success/failure
```

### GitHub Actions Workflow Flow

```
Workflow Trigger
  │
  ├─→ Job: deploy
  │   │
  │   ├─→ Step: Checkout Code
  │   │   └─→ actions/checkout@v3
  │   │
  │   ├─→ Step: Setup Node.js
  │   │   └─→ actions/setup-node@v3
  │   │
  │   ├─→ Step: Install Dependencies
  │   │   └─→ npm ci
  │   │
  │   ├─→ Step: Install Salesforce CLI
  │   │   └─→ npm install -g @salesforce/cli
  │   │
  │   ├─→ Step: Authenticate
  │   │   └─→ sf org login sfdx-url
  │   │
  │   ├─→ Step: Deploy Metadata
  │   │   └─→ sf project deploy start
  │   │
  │   └─→ Step: Deploy S-Docs ✨
  │       └─→ npm run sdocs:upsertAll
  │
  └─→ Job Results → Notifications
```

---

## 📁 File System Organization

```
liquibase-changes/
│
├── .github/
│   └── workflows/                    # GitHub Actions workflows
│       ├── deployCode.yml           # Main deployment workflow
│       └── deployCodeSOA.yml        # Scratch org workflow
│
├── data/
│   └── sdocsTemplates/              # S-Docs template storage
│       ├── README.md                # Template documentation
│       ├── *.json                   # Template definition files
│       └── (add more templates)
│
├── scripts/
│   └── sdocs-upserter.js           # Main deployment script
│
├── .env.example                     # Environment config template
├── .gitignore                       # Git ignore rules
├── package.json                     # Node.js project config
│
├── README.md                        # Task requirements
├── SETUP_GUIDE.md                   # Comprehensive setup guide
├── QUICKSTART.md                    # Quick start guide
└── ARCHITECTURE.md                  # This file
```

---

## 🔐 Security Architecture

### Authentication Flow

```
┌─────────────────────────────────────────────────────┐
│                  Developer Machine                   │
│                                                      │
│  sf org login web --alias myorg                     │
│  └─→ Opens browser for OAuth                        │
│      └─→ Stores credentials in .sfdx/               │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│              Scripts read auth from:                 │
│         ~/.sfdx/ or ~/.sf/ directory                │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│                Salesforce Org                        │
└─────────────────────────────────────────────────────┘
```

### CI/CD Authentication

```
┌─────────────────────────────────────────────────────┐
│              GitHub Repository Secrets               │
│                                                      │
│  SFDX_AUTH_URL = force://...                        │
│  SFDX_DEVHUB_AUTH_URL = force://...                │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│           GitHub Actions Workflow                    │
│                                                      │
│  echo "$SECRET" > auth.txt                          │
│  sf org login sfdx-url --sfdx-url-file auth.txt    │
│  rm auth.txt                                        │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│              Temporary Auth Session                  │
│         (Exists only during workflow run)           │
└─────────────────────────────────────────────────────┘
```

**Security Best Practices:**
- Auth tokens stored in GitHub Secrets
- Auth files deleted immediately after use
- No credentials in source code
- Session-based authentication in CI/CD

---

## 🔄 Data Flow

### Template Deployment Data Flow

```
Template JSON File
  │
  │ {
  │   "Name": "Template Name",
  │   "SDOC__Template_Type__c": "Document",
  │   ...
  │ }
  │
  ▼
scripts/sdocs-upserter.js
  │
  ├─→ Read file content
  │   └─→ fs.readFileSync()
  │
  ├─→ Parse JSON
  │   └─→ JSON.parse()
  │
  ├─→ Validate structure
  │   └─→ Check required fields
  │
  ├─→ Connect to Salesforce
  │   └─→ Use Salesforce CLI/API
  │
  └─→ Upsert template
      │
      ├─→ If template exists (by Name)
      │   └─→ Update existing record
      │
      └─→ If template doesn't exist
          └─→ Insert new record
```

### Error Handling Flow

```
Deployment Starts
  │
  ├─→ Connection Error?
  │   └─→ Yes → Log error → Exit(1)
  │
  ├─→ Template Read Error?
  │   └─→ Yes → Log error → Continue to next
  │
  ├─→ Validation Error?
  │   └─→ Yes → Log error → Continue to next
  │
  └─→ Deployment Error?
      └─→ Yes → Log error → Continue to next

All templates processed
  │
  ├─→ Any failures? → Exit(1)
  └─→ All success → Exit(0)
```

---

## 🎯 Integration Points

### 1. Salesforce CLI Integration

```javascript
// Check connection
execSync('sf org display --json')

// Deploy metadata
execSync('sf project deploy start')

// Assign permissions
execSync('sf org assign permset --name SDOC_Admin')
```

### 2. File System Integration

```javascript
// Read templates
fs.readdirSync('data/sdocsTemplates')
  .filter(file => file.endsWith('.json'))

// Parse template
JSON.parse(fs.readFileSync(templateFile, 'utf-8'))
```

### 3. GitHub Actions Integration

```yaml
# Trigger on push
on:
  push:
    branches: [main, develop]

# Run deployment
- name: Deploy S-Docs Templates
  run: npm run sdocs:upsertAll
```

---

## 🔧 Extension Points

### Adding New Setup Targets

To add a new environment setup (e.g., staging):

1. **Add npm script** in package.json:
```json
"setup:dev:staging": "npm run setup:dev:base && npm run sdocs:upsertAll"
```

2. **Create workflow** (optional):
```yaml
# .github/workflows/deployStaging.yml
- name: Deploy to Staging
  run: npm run setup:dev:staging
```

### Adding New Template Types

To support new template types:

1. **Add template JSON** in data/sdocsTemplates/:
```json
{
  "Name": "New Template Type",
  "SDOC__Template_Type__c": "NewType",
  ...
}
```

2. **No code changes needed** - script automatically picks up new files

### Custom Validation Rules

To add custom validation in scripts/sdocs-upserter.js:

```javascript
function validateTemplate(templateData) {
  // Add custom validation
  if (!templateData.SDOC__Object_API_Name__c) {
    throw new Error('Object API Name is required');
  }
  // Add more rules...
}
```

---

## 📊 Performance Considerations

### Template Processing

```
Sequential Processing:
  Template 1 → Template 2 → Template 3 → ...
  Time: O(n) where n = number of templates
```

**Optimization Opportunities:**
- Batch API operations (process multiple templates in one API call)
- Parallel processing (process templates concurrently)
- Caching (avoid re-processing unchanged templates)

### Workflow Execution

```
Typical Workflow Time:
  Checkout:        ~10s
  Setup Node:      ~30s
  Install deps:    ~60s
  Install SF CLI:  ~120s
  Authenticate:    ~5s
  Deploy metadata: ~300s (varies)
  Deploy S-Docs:   ~30s ✨
  ─────────────────────
  Total:           ~555s (~9 minutes)
```

---

## 🔍 Monitoring and Logging

### Log Levels

```
scripts/sdocs-upserter.js provides:

  ✓ Success (Green)
  ⚠ Warning (Yellow)
  ✗ Error (Red)
  ℹ Info (Blue/Cyan)
```

### Workflow Logs

GitHub Actions provides:
- Step-by-step execution logs
- Timing information
- Success/failure status
- Error details

**Access logs:**
1. Go to repository → Actions tab
2. Select workflow run
3. Click on job
4. View step logs

---

## 🚀 Deployment Strategies

### Strategy 1: Manual Deployment
```bash
sf org login web --alias target
npm run sdocs:upsertAll
```
**Use case:** Ad-hoc deployments, testing

### Strategy 2: Automated CI/CD
```yaml
on:
  push:
    branches: [main]
```
**Use case:** Production deployments, scheduled updates

### Strategy 3: Post-Refresh
```bash
npm run setup:dev:lowerSandbox
```
**Use case:** Sandbox refreshes, data restoration

---

## 📝 Summary

This architecture provides:

✅ **Automated S-Docs deployment** across all environments  
✅ **Consistent deployment process** (same command everywhere)  
✅ **Error handling and logging** for troubleshooting  
✅ **CI/CD integration** for automated workflows  
✅ **Extensibility** for future enhancements  
✅ **Security** through proper authentication  
✅ **Documentation** for easy onboarding  

---

**For implementation details, see:**
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Setup and usage
- [QUICKSTART.md](QUICKSTART.md) - Quick start
- [data/sdocsTemplates/README.md](data/sdocsTemplates/README.md) - Template documentation
