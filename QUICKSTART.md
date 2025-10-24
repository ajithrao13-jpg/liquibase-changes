# Quick Start Guide - S-Docs Deployment Automation

## 🚀 Get Started in 5 Minutes

This guide will help you quickly set up and run the S-Docs deployment automation for the MBMS Salesforce project.

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
# Login to your Salesforce org (using the actual target org alias)
sf org login web --alias mbms-salesforce

# Verify connection
sf org display --target-org mbms-salesforce
```

---

## Step 3: Deploy S-Docs Templates (1 minute)

```bash
# Deploy all S-Docs templates to your connected org
npm run sdocs:upsertAll
```

This command performs the following steps:
1. Queries for the MBMS RecordType ID
2. Injects the RecordType ID into templates
3. Upserts all S-Docs templates from `data/sdocsTemplates/`

The templates will be deployed to your authenticated Salesforce org.


---

## Step 4: Test Other Setup Commands (1 minute)

```bash
# Run local development setup (creates scratch org and deploys everything including S-Docs)
npm run setup:dev:local

# Run CI setup (for continuous integration environments)
npm run setup:dev:ci

# Run lower sandbox setup (for post-refresh scenarios)
npm run setup:dev:lowerSandbox

# Run higher sandbox setup (for production-like sandboxes)
npm run setup:dev:higherSandbox
```

All setup scripts automatically include S-Docs deployment as the final step before completion.

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

1. **Local Development**: `npm run setup:dev:local` - Creates scratch org with all data and S-Docs
2. **CI/CD Environments**: `npm run setup:dev:ci` - Automated CI deployments
3. **Lower Sandbox Deployments**: `npm run setup:dev:lowerSandbox` - Post-refresh automation
4. **Higher Sandbox Deployments**: `npm run setup:dev:higherSandbox` - Production-like environments
5. **Standalone S-Docs Deployment**: `npm run sdocs:upsertAll` - Deploy only S-Docs templates

---

## 📚 Next Steps

- **Add Your Templates**: Add `.json` files to `data/sdocsTemplates/`
- **Customize Scripts**: Modify scripts in `package.json` as needed
- **Setup CI/CD**: Configure GitHub Actions workflows
- **Read Full Guide**: See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed explanations

---

## 🆘 Need Help?

### Common Commands

```bash
# View connected orgs
sf org list

# Set default org
sf config set target-org mbms-salesforce

# View org details
sf org display --target-org mbms-salesforce

# Deploy S-Docs only
npm run sdocs:upsertAll

# View available scripts
npm run
```

### Quick Troubleshooting

**Problem**: "Unable to detect connected Salesforce org"
```bash
sf org login web --alias mbms-salesforce
sf config set target-org mbms-salesforce
```

**Problem**: "No template files found"
- Check that `.json` files exist in `data/sdocsTemplates/`

**Problem**: Missing dependencies
```bash
npm install
npm run install:toolbox
npm run install:skuid
npm run install:texei
```

### Get More Help

- Full setup guide: [SETUP_GUIDE.md](SETUP_GUIDE.md)
- Troubleshooting section: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Code explanations: [SETUP_GUIDE.md#code-explanation](SETUP_GUIDE.md#code-explanation)

---

**Happy Deploying! 🎉**

