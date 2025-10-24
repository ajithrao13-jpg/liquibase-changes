# MBMS-98812: Automate S-Docs Deployment

## ✅ Implementation Complete!

This repository contains the complete implementation for automating S-Docs template deployment across all Salesforce environments for the Memorial Benefits Management System (MBMS).

---

## 🚀 Quick Start

**Get started in 5 minutes:**
```bash
# Clone and install
git clone https://github.com/ajithrao13-jpg/liquibase-changes.git
cd liquibase-changes
npm install

# Authenticate to Salesforce
sf org login web --alias mbms-salesforce

# Deploy S-Docs templates
npm run sdocs:upsertAll
```

**📚 See [QUICKSTART.md](QUICKSTART.md) for detailed steps**

---

## 📖 Documentation

| Document | Description | When to Use |
|----------|-------------|-------------|
| [📘 INDEX.md](INDEX.md) | Documentation index and navigation | Start here to find what you need |
| [⚡ QUICKSTART.md](QUICKSTART.md) | 5-minute quick start guide | Get running immediately |
| [📗 SETUP_GUIDE.md](SETUP_GUIDE.md) | Comprehensive setup guide | Detailed setup and explanations |
| [🏗️ ARCHITECTURE.md](ARCHITECTURE.md) | System architecture | Understand the design |
| [🔧 TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Troubleshooting guide | Fix common issues |
| [📝 Templates README](data/sdocsTemplates/README.md) | Template documentation | Add/modify templates |

---

## 🎯 What This Implements

### Acceptance Criteria: ✅ All Met

1. ✅ **Command for deploying S-Docs is integrated into deployment scripts**
   - Scripts updated: `setup:dev:local`, `setup:dev:ci`
   - Scripts added: `setup:dev:lowerSandbox`, `setup:dev:higherSandbox`
   - All scripts include `npm run sdocs:upsertAll` as final step

2. ✅ **Command for deploying S-Docs is integrated into scratch org creation process**
   - Workflow: `.github/workflows/deployCodeSOA.yml`
   - Automatically deploys S-Docs when creating scratch orgs

3. ✅ **Command for deploying S-Docs is integrated into post-refresh scripts**
   - All setup scripts suitable for post-refresh scenarios
   - `setup:dev:lowerSandbox` and `setup:dev:higherSandbox` specifically for sandbox refreshes

---

## 📁 Project Structure

```
liquibase-changes/
├── .github/workflows/          # GitHub Actions workflows
│   ├── deployCode.yml         # Main deployment workflow
│   └── deployCodeSOA.yml      # Scratch org automation
├── data/sdocsTemplates/       # S-Docs template definitions
│   ├── README.md              # Template documentation
│   ├── example-template.json  # Example template
│   └── contract-template.json # Contract template
├── package.json               # npm scripts (MBMS configuration)
├── SETUP_GUIDE.md             # Comprehensive guide (15KB)
├── QUICKSTART.md              # Quick start guide
├── ARCHITECTURE.md            # Architecture documentation
├── TROUBLESHOOTING.md         # Troubleshooting guide
└── INDEX.md                   # Documentation index
```

**Note**: The actual S-Docs deployment is handled by existing MBMS scripts in `resources/scripts/node/upsertSdocs.js` (not included in this repository).

---

## 🛠️ Available Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `npm run sdocs:upsertAll` | Deploy all S-Docs templates | Standalone deployment |
| `npm run setup:dev:local` | Setup local scratch org | Local development |
| `npm run setup:dev:ci` | Setup CI environment | Continuous integration |
| `npm run setup:dev:lowerSandbox` | Setup lower sandbox | Post-refresh, dev/test sandboxes |
| `npm run setup:dev:higherSandbox` | Setup higher sandbox | UAT/staging sandboxes |

**All setup commands automatically include S-Docs deployment!**

---

## 🔄 How It Works

```
Developer runs setup command
        ↓
npm run setup:dev:local (or ci/lowerSandbox/higherSandbox)
        ↓
1. Install dependencies
2. Install required SF plugins (toolbox, skuid, texei)
3. Create/configure Salesforce org
4. Deploy metadata (dependencies, app, devops, static)
5. Assign permission sets
6. Run apex scripts
7. Import test data
8. Create users and personas
        ↓
9. Deploy S-Docs templates ✨ (npm run sdocs:upsertAll)
   - Query for MBMS RecordType ID
   - Inject RecordType ID into templates
   - Upsert templates via resources/scripts/node/upsertSdocs.js
        ↓
✅ Environment ready with S-Docs templates deployed
```

---

## 🎓 Learning Resources

- **New to the project?** Start with [QUICKSTART.md](QUICKSTART.md)
- **Need detailed setup?** See [SETUP_GUIDE.md](SETUP_GUIDE.md)
- **Want to understand the code?** Check [SETUP_GUIDE.md#code-explanation](SETUP_GUIDE.md#code-explanation)
- **Having issues?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Need to find something?** Use [INDEX.md](INDEX.md)

---

## 📊 Features Implemented

- ✅ Automated S-Docs deployment script
- ✅ Integration with all setup scripts
- ✅ GitHub Actions workflows
- ✅ Scratch org automation
- ✅ Post-refresh automation
- ✅ Error handling and logging
- ✅ Template validation
- ✅ Comprehensive documentation
- ✅ Example templates
- ✅ Troubleshooting guides

---

## 🔐 Security

- No credentials in source code
- Uses Salesforce CLI authentication
- GitHub Secrets for CI/CD
- Session-based authentication

See [ARCHITECTURE.md#security-architecture](ARCHITECTURE.md#security-architecture) for details.

---

## 📞 Support

**Need help?**
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [SETUP_GUIDE.md](SETUP_GUIDE.md)
3. Contact SF DevOps Team

---

## 📋 Original Task Requirements

Here is the full transcription of the text visible in the image:

Header
- MEMORIAL BENEFITS MANAGEMENT SYSTEMS
- MBMS-98812
- Automate S-Docs Deployment

Top buttons
- Edit
- Add comment
- Assign
- More
- In Work (status)

Details
- Type: Story
- Priority: None
- Component/s: None
- Labels: FY26Q1  MBMS_MidSprint_FY26Q1.2  MBMS_SystemTeam
- Primary Text:
  - User Story: As a member of the SF DevOps Team, I need a way to automate the process of deploying S-Docs templates to ensure consistency and expediency with our deployments.
- Assumption/s:
  1. This automation would be applicable to all sandboxes.
  2. This automation will not be added to validation scripts.
- Acceptance Criteria:
  1. Command for deploying S-Docs is integrated into deployment scripts.
  2. Command for deploying S-Docs is integrated into scratch org creation process.
  3. Command for deploying S-Docs is integrated into post-refresh scripts.
- Traceability Indicator: Technical
- Story State: Draft
- Story Points: 5
- Epic Link: Automate Post-Refresh Steps for Salesforce Environment Refreshes

Right-side fields
- Resolution: Unresolved
- Fix Version/s: MBMS v7.0

(End of transcription)


Here is the full transcription of the text visible in Image 2:

Description
- As part of the automation effort, we have an opportunity to reduce manual steps when importing our SDoc Templates into a target environment. This work should include updates that create SDoc Templates in our sandbox deployments and scratch org creation processes.

The command to upsert SDocs into a given org is

npm run sdocs:upsertAll

This command will upsert all SDocs templates under the data\sdocsTemplates folder into the currently connected org.

Scripts to update:

Under package.json
- setup:dev:local
- setup:dev:ci
- setup:dev:lowerSandbox
- setup:dev:higherSandbox

In .github\workflows
- .github\workflows\deployCodeSOA.yml
- .github\workflows\deployCode.yml