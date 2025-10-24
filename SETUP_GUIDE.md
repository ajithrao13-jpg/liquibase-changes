# S-Docs Deployment Automation - Setup Guide

> **Note**: This guide documents the S-Docs deployment automation for the MBMS Salesforce project. The actual deployment logic is implemented in the MBMS codebase at `resources/scripts/node/upsertSdocs.js`. This repository provides the integration points and documentation.

## 📋 Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Project Structure](#project-structure)
5. [Configuration](#configuration)
6. [Usage](#usage)
7. [Code Explanation](#code-explanation)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project automates the deployment of S-Docs templates to Salesforce environments. It addresses the user story from **MBMS-98812**: 
> "As a member of the SF DevOps Team, I need a way to automate the process of deploying S-Docs templates to ensure consistency and expediency with our deployments."

### Acceptance Criteria Met:
✅ Command for deploying S-Docs is integrated into deployment scripts  
✅ Command for deploying S-Docs is integrated into scratch org creation process  
✅ Command for deploying S-Docs is integrated into post-refresh scripts  

### Implementation:
The S-Docs deployment is implemented through the existing MBMS script infrastructure:
- **Query RecordType**: `npm run sdocs:query:recordTypeId` - Queries for MBMS RecordType ID
- **Inject RecordType**: `npm run sdocs:injectRecordTypeId` - Injects ID into templates
- **Upsert Templates**: `node resources/scripts/node/upsertSdocs.js` - Deploys templates
- **Complete Process**: `npm run sdocs:upsertAll` - Runs all three steps

---

## 🔧 Prerequisites

Before you begin, ensure you have the following installed:

### Required Software:
1. **Node.js** (version 16 or higher)
   - Download from: https://nodejs.org/
   - Verify installation: `node --version`

2. **npm** (comes with Node.js)
   - Verify installation: `npm --version`

3. **Salesforce CLI**
   - Install: `npm install -g @salesforce/cli`
   - Verify installation: `sf version`

4. **Git**
   - Download from: https://git-scm.com/
   - Verify installation: `git --version`

5. **MBMS Required Plugins**
   - Install toolbox: `npm run install:toolbox`
   - Install skuid: `npm run install:skuid`
   - Install texei: `npm run install:texei`

### Salesforce Requirements:
- Access to a Salesforce DevHub (for scratch orgs)
- S-Docs package installed in target orgs
- Appropriate permissions to create/modify S-Docs templates
- MBMS RecordType configured in target org

---

## 📦 Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/ajithrao13-jpg/liquibase-changes.git
cd liquibase-changes
```

### Step 2: Install Dependencies
```bash
npm install
```

This command will install all MBMS project dependencies including linting tools, test frameworks, and development utilities.

### Step 3: Authenticate to Salesforce

#### For Sandbox/Production:
```bash
# Authenticate using web login (using MBMS org alias)
sf org login web --alias mbms-salesforce

# Or authenticate using auth URL
sf org login sfdx-url --sfdx-url-file path/to/auth.txt --alias mbms-salesforce
```

#### For DevHub (required for scratch orgs):
```bash
sf org login web --alias devhub --set-default-dev-hub
```

### Step 4: Install Required Salesforce Plugins
```bash
# Install all required plugins
npm run install:toolbox
npm run install:skuid
npm run install:texei
```

### Step 5: Verify Installation
```bash
# Check if you can see your authenticated orgs
sf org list

# Test the S-Docs deployment command
npm run sdocs:upsertAll
```

---

## 📁 Project Structure

```
liquibase-changes/
│
├── .github/
│   └── workflows/              # GitHub Actions workflows
│       ├── deployCode.yml      # Main deployment workflow
│       └── deployCodeSOA.yml   # Scratch org automation workflow
│
├── data/
│   └── sdocsTemplates/         # S-Docs template definitions
│       ├── README.md           # Template documentation
│       ├── example-template.json
│       └── contract-template.json
│
├── .gitignore                  # Git ignore rules
├── package.json                # MBMS npm scripts and dependencies
├── README.md                   # Project overview
├── SETUP_GUIDE.md              # This file
├── QUICKSTART.md               # Quick start guide
├── ARCHITECTURE.md             # Architecture documentation
├── TROUBLESHOOTING.md          # Troubleshooting guide
└── INDEX.md                    # Documentation index
```

**Note**: The actual S-Docs deployment scripts are part of the main MBMS codebase at `resources/scripts/node/` (not shown in this repository).

### Key Files Explained:

#### `package.json`
Contains npm scripts and project metadata for the MBMS Salesforce project:
- **sdocs:upsertAll**: Main command that queries RecordType, injects it, and deploys all S-Docs templates
- **sdocs:query:recordTypeId**: Queries for the MBMS RecordType ID
- **sdocs:injectRecordTypeId**: Injects the RecordType ID into template files
- **setup:dev:local**: Full local scratch org setup including S-Docs deployment
- **setup:dev:ci**: CI environment setup including S-Docs deployment  
- **setup:dev:lowerSandbox**: Lower sandbox setup including S-Docs deployment
- **setup:dev:higherSandbox**: Higher sandbox setup including S-Docs deployment

#### S-Docs Deployment Process
The deployment is handled by three chained commands in `sdocs:upsertAll`:
1. Query for MBMS RecordType ID from Salesforce
2. Inject the RecordType ID into template JSON files
3. Execute `resources/scripts/node/upsertSdocs.js` to deploy templates

#### `.github/workflows/deployCode.yml`
GitHub Actions workflow for deploying to persistent environments:
- Triggers on push to main/develop branches
- Authenticates to Salesforce
- Deploys metadata
- **Automatically deploys S-Docs templates**

#### `.github/workflows/deployCodeSOA.yml`
GitHub Actions workflow for scratch org automation:
- Creates scratch org
- Deploys source code
- **Automatically deploys S-Docs templates**
- Runs setup scripts

---

## ⚙️ Configuration

### Adding S-Docs Templates

S-Docs templates are defined as JSON files in `data/sdocsTemplates/`.

#### Template Structure:
```json
{
  "Name": "Template Name",
  "SDOC__Template_Type__c": "Document",
  "SDOC__Description__c": "Template description",
  "SDOC__Template_Status__c": "Active",
  "SDOC__Object_API_Name__c": "Account",
  "SDOC__File_Type__c": "PDF",
  "SDOC__Template_Label__c": "Display Label"
}
```

#### Required Fields:
- **Name**: Unique identifier for the template
- **SDOC__Template_Type__c**: Type of template (Document, Email, etc.)
- **SDOC__Object_API_Name__c**: Salesforce object this template applies to

#### To Add a New Template:
1. Create a new `.json` file in `data/sdocsTemplates/`
2. Define the template structure
3. Run `npm run sdocs:upsertAll` to deploy

### Environment Variables (Optional)

Create a `.env` file for environment-specific settings:
```bash
# Salesforce Org Settings
SF_DEFAULT_ORG=myorg
SF_TARGET_USERNAME=user@example.com

# Deployment Settings
NODE_ENV=production
DEBUG_MODE=false
```

### GitHub Secrets (for CI/CD)

Configure these secrets in your GitHub repository:

1. **SFDX_AUTH_URL**: Authentication URL for target org
   ```bash
   # Generate auth URL
   sf org display --verbose --json --target-org myorg
   ```

2. **SFDX_DEVHUB_AUTH_URL**: Authentication URL for DevHub
   ```bash
   sf org display --verbose --json --target-org devhub
   ```

To add secrets:
1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret name and value

---

## 🚀 Usage

### Local Development

#### Deploy S-Docs to Current Org:
```bash
npm run sdocs:upsertAll
```

#### Setup Local Development Environment:
```bash
npm run setup:dev:local
```
This runs base setup and deploys S-Docs templates.

#### Setup CI Environment:
```bash
npm run setup:dev:ci
```

#### Setup Lower Sandbox:
```bash
npm run setup:dev:lowerSandbox
```

#### Setup Higher Sandbox:
```bash
npm run setup:dev:higherSandbox
```

### Automated Workflows

#### Trigger Deployment Workflow:
1. Push code to `main` or `develop` branch
2. Or manually trigger from GitHub Actions tab

#### Trigger Scratch Org Creation:
1. Create a pull request
2. Or manually trigger from GitHub Actions tab with parameters:
   - Scratch org alias
   - Duration (days)

### Command Line Examples

#### Example 1: Deploy to Specific Org
```bash
# Set target org
sf config set target-org myorg

# Deploy S-Docs
npm run sdocs:upsertAll
```

#### Example 2: Create Scratch Org and Deploy
```bash
# Create scratch org
sf org create scratch -f config/project-scratch-def.json -a myscratch

# Deploy S-Docs to scratch org
sf config set target-org myscratch
npm run sdocs:upsertAll
```

#### Example 3: Post-Refresh Deployment
```bash
# After sandbox refresh
sf org login web --alias refreshed-sandbox

# Run post-refresh setup (includes S-Docs)
npm run setup:dev:lowerSandbox
```

---

## 📖 Code Explanation

### How the S-Docs Deployment Works

#### 1. Entry Point (`npm run sdocs:upsertAll`)
When you run this command, npm executes a chain of three commands defined in `package.json`:
```json
"scripts": {
  "sdocs:query:recordTypeId": "sf data query --query \"Select Id FROM RecordType WHERE Name = 'MBMS' AND SObjectType = 'SDOC__SDTemplate__c'\" --output-file sdocsRecordTypeId.csv --result-format json",
  "sdocs:injectRecordTypeId": "node resources/scripts/node/injectSdocsRecordTypeId.js",
  "sdocs:upsertAll": "npm run sdocs:query:recordTypeId && npm run sdocs:injectRecordTypeId && node resources/scripts/node/upsertSdocs.js"
}
```

#### 2. Step-by-Step Process

##### Step 1: Query MBMS RecordType ID
```bash
npm run sdocs:query:recordTypeId
```
**What it does**:
- Queries Salesforce for the MBMS RecordType on the SDOC__SDTemplate__c object
- Saves the result to `sdocsRecordTypeId.csv` in JSON format
- This RecordType ID is required for all S-Docs templates in the MBMS org

**Example output**:
```json
{
  "Id": "0123456789ABCDE"
}
```

##### Step 2: Inject RecordType ID into Templates
```bash
npm run sdocs:injectRecordTypeId
```
**What it does**:
- Reads the RecordType ID from `sdocsRecordTypeId.csv`
- Reads all JSON template files from `data/sdocsTemplates/`
- Injects the `RecordTypeId` field into each template
- Prepares templates for deployment with the correct RecordType

**Implementation** (in `resources/scripts/node/injectSdocsRecordTypeId.js`):
- Parses the query results
- Updates each template JSON file
- Ensures all templates have the MBMS RecordType

##### Step 3: Upsert Templates to Salesforce
```bash
node resources/scripts/node/upsertSdocs.js
```
**What it does**:
- Reads all prepared template files from `data/sdocsTemplates/`
- Connects to the authenticated Salesforce org
- Upserts (inserts or updates) each template using Salesforce APIs
- Provides feedback on success/failure for each template

**Key features**:
- Uses Salesforce CLI or APIs for deployment
- Handles both new templates (insert) and existing templates (update)
- Validates template structure before deployment
- Provides detailed error messages if deployment fails

#### 3. Integration with Setup Scripts

All MBMS setup scripts now include S-Docs deployment as the final step:

```json
"setup:dev:local": "... && npm run sdocs:upsertAll && ...",
"setup:dev:ci": "... && npm run sdocs:upsertAll",
"setup:dev:lowerSandbox": "... && npm run sdocs:upsertAll",
"setup:dev:higherSandbox": "... && npm run sdocs:upsertAll"
```

The S-Docs deployment runs after:
1. Installing dependencies and plugins
2. Creating/configuring the Salesforce org
3. Deploying all metadata (dependencies, app, devops, static)
4. Assigning permission sets
5. Running Apex scripts
6. Importing test data
7. Creating users and personas

This ensures S-Docs templates are always deployed as part of the environment setup.

### How GitHub Workflows Work

#### Deployment Workflow (`deployCode.yml`)

**Trigger**: Push to main/develop or manual trigger
```yaml
on:
  push:
    branches: [main, develop]
  workflow_dispatch:
```

**Key Steps**:
1. **Checkout Code**: Gets latest code from repository
2. **Setup Node.js**: Installs Node.js environment
3. **Install Dependencies**: Runs `npm ci` (clean install)
4. **Install Salesforce CLI**: Installs SF CLI globally
5. **Authenticate**: Uses secret auth URL to login
6. **Deploy Metadata**: Deploys Salesforce source
7. **Deploy S-Docs**: Runs `npm run sdocs:upsertAll` ✨
8. **Run Tests**: Validates deployment

**S-Docs Integration**:
```yaml
- name: Deploy S-Docs Templates
  run: npm run sdocs:upsertAll
```
This automatically deploys S-Docs after metadata deployment.

#### Scratch Org Workflow (`deployCodeSOA.yml`)

**Trigger**: Pull request or manual trigger

**Key Steps**:
1. **Checkout Code**
2. **Setup Node.js**
3. **Install Dependencies**
4. **Authenticate to DevHub**
5. **Create Scratch Org**
6. **Deploy Source**
7. **Deploy S-Docs** ✨
8. **Run Setup Scripts**
9. **Assign Permissions**

**S-Docs Integration**:
```yaml
- name: Setup and Deploy S-Docs Templates
  run: npm run sdocs:upsertAll
```
This ensures S-Docs are deployed when scratch org is created.

### Integration with Setup Scripts

All setup scripts automatically include S-Docs deployment:

```json
"setup:dev:local": "npm run setup:dev:base && npm run sdocs:upsertAll"
```

The `&&` operator means:
1. First run base setup
2. Then (only if successful) run S-Docs deployment

This ensures S-Docs are always deployed as part of environment setup.

---

## 🔍 Troubleshooting

### Common Issues

#### Issue 1: "Unable to detect connected Salesforce org"
**Solution**:
```bash
# Authenticate to an org
sf org login web --alias myorg
sf config set target-org myorg

# Verify authentication
sf org display
```

#### Issue 2: "No template files found"
**Solution**:
- Check that `.json` files exist in `data/sdocsTemplates/`
- Verify file names end with `.json`
- Ensure files contain valid JSON

#### Issue 3: "Permission denied" when running scripts
**Solution**:
```bash
# Make script executable (Unix/Mac)
chmod +x scripts/sdocs-upserter.js

# Or run with node explicitly
node scripts/sdocs-upserter.js
```

#### Issue 4: GitHub workflow fails on authentication
**Solution**:
1. Verify `SFDX_AUTH_URL` secret is set correctly
2. Generate new auth URL:
   ```bash
   sf org display --verbose --json
   ```
3. Copy the `sfdxAuthUrl` value to GitHub secrets

#### Issue 5: S-Docs package not found in org
**Solution**:
- Install S-Docs package from Salesforce AppExchange
- Verify package is installed: `sf package installed list`

### Debug Mode

Enable detailed logging:
```bash
# Set debug environment variable
export DEBUG=true

# Run with verbose output
npm run sdocs:upsertAll
```

### Getting Help

1. Check Salesforce CLI documentation: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/
2. Check S-Docs documentation
3. Review workflow logs in GitHub Actions tab
4. Contact SF DevOps team

---

## 🎓 Learning Resources

### Salesforce CLI
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)

### GitHub Actions
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

### Node.js & npm
- [npm Scripts Guide](https://docs.npmjs.com/cli/v9/using-npm/scripts)
- [Node.js Documentation](https://nodejs.org/docs/)

---

## 📝 Next Steps

After completing the setup:

1. **Add Your Templates**: Create S-Docs template JSON files in `data/sdocsTemplates/`
2. **Test Locally**: Run `npm run sdocs:upsertAll` to test deployment
3. **Customize Workflows**: Modify GitHub workflows for your specific needs
4. **Add Tests**: Create automated tests for template validation
5. **Document Custom Templates**: Document any custom template fields

---

## ✅ Success Criteria Checklist

- [ ] All prerequisites installed
- [ ] Repository cloned and dependencies installed
- [ ] Authenticated to Salesforce org
- [ ] S-Docs templates added to `data/sdocsTemplates/`
- [ ] Successfully ran `npm run sdocs:upsertAll`
- [ ] GitHub workflows configured with secrets
- [ ] Tested deployment to sandbox
- [ ] Tested scratch org creation with S-Docs deployment
- [ ] Team trained on using automation

---

## 📞 Support

For issues or questions:
- SF DevOps Team: [contact info]
- JIRA: MBMS-98812
- Documentation: This guide

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-24  
**Maintained By**: SF DevOps Team
