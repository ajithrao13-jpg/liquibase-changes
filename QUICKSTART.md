# Quick Start Guide - S-Docs Deployment Automation

## 🚀 Get Started in 5 Minutes

This guide will help you quickly set up and run the S-Docs deployment automation.

---

## Prerequisites Check

Before starting, verify you have:
```bash
node --version    # Should show v16 or higher
npm --version     # Should show 8 or higher
sf version        # Should show Salesforce CLI
git --version     # Should show git installed
```

If anything is missing, see [SETUP_GUIDE.md](SETUP_GUIDE.md#prerequisites) for installation instructions.

---

## Step 1: Clone and Install (2 minutes)

```bash
# Clone the repository
git clone https://github.com/ajithrao13-jpg/liquibase-changes.git
cd liquibase-changes

# Install dependencies
npm install
```

---

## Step 2: Authenticate to Salesforce (1 minute)

```bash
# Login to your Salesforce org
sf org login web --alias myorg

# Verify connection
sf org display
```

---

## Step 3: Deploy S-Docs Templates (1 minute)

```bash
# Deploy all S-Docs templates to your connected org
npm run sdocs:upsertAll
```

You should see output like:
```
========================================
S-Docs Template Upserter
========================================

Step 1: Verifying Salesforce connection...
✓ Connected to org: user@example.com

Step 2: Reading template files...
Found 2 template file(s)

Step 3: Upserting templates...

Processing: example-template.json
  Template Name: Example Document Template
  ✓ Template upserted successfully

Processing: contract-template.json
  Template Name: Standard Contract Template
  ✓ Template upserted successfully

========================================
Summary
========================================
Total templates: 2
Successful: 2
Failed: 0
========================================
```

---

## Step 4: Test Other Setup Commands (1 minute)

```bash
# Run local development setup (includes S-Docs deployment)
npm run setup:dev:local

# Run sandbox setup
npm run setup:dev:lowerSandbox
```

---

## ✅ You're Done!

You've successfully:
- ✅ Installed the project
- ✅ Authenticated to Salesforce
- ✅ Deployed S-Docs templates
- ✅ Tested setup scripts

---

## 🎯 What's Automated?

This project automates S-Docs deployment in:

1. **Local Development**: `npm run setup:dev:local`
2. **CI/CD Environments**: `npm run setup:dev:ci`
3. **Sandbox Deployments**: Via GitHub Actions
4. **Scratch Org Creation**: Via GitHub Actions
5. **Post-Refresh Scripts**: All setup scripts include S-Docs

---

## 📚 Next Steps

- **Add Your Templates**: Add `.json` files to `data/sdocsTemplates/`
- **Customize Scripts**: Modify `package.json` scripts for your needs
- **Setup CI/CD**: Configure GitHub Actions workflows
- **Read Full Guide**: See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed explanations

---

## 🆘 Need Help?

### Common Commands

```bash
# View connected orgs
sf org list

# Set default org
sf config set target-org myorg

# View org details
sf org display

# Deploy S-Docs
npm run sdocs:upsertAll

# View available scripts
npm run
```

### Quick Troubleshooting

**Problem**: "Unable to detect connected Salesforce org"
```bash
sf org login web --alias myorg
sf config set target-org myorg
```

**Problem**: "No template files found"
- Check that `.json` files exist in `data/sdocsTemplates/`

**Problem**: "Permission denied"
```bash
node scripts/sdocs-upserter.js
```

### Get More Help

- Full setup guide: [SETUP_GUIDE.md](SETUP_GUIDE.md)
- Troubleshooting section: [SETUP_GUIDE.md#troubleshooting](SETUP_GUIDE.md#troubleshooting)
- Code explanations: [SETUP_GUIDE.md#code-explanation](SETUP_GUIDE.md#code-explanation)

---

**Happy Deploying! 🎉**
