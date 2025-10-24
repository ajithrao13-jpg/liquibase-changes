# Troubleshooting Guide - S-Docs Deployment Automation

## 🔍 Quick Diagnostic Commands

Before troubleshooting, run these commands to gather information:

```bash
# Check Node.js version
node --version

# Check npm version
npm --version

# Check Salesforce CLI version
sf version

# List authenticated orgs
sf org list

# Display current org
sf org display

# Check current directory
pwd

# List project files
ls -la

# Check npm scripts
npm run
```

---

## 🚨 Common Issues and Solutions

### Issue 1: "Unable to detect connected Salesforce org"

**Symptoms:**
```
✗ Fatal error: Unable to detect connected Salesforce org. Please authenticate first.
```

**Causes:**
- Not authenticated to any Salesforce org
- Salesforce CLI not installed
- Auth session expired

**Solutions:**

#### Solution A: Authenticate to Salesforce
```bash
# Web login (recommended)
sf org login web --alias myorg

# Set as default
sf config set target-org myorg

# Verify connection
sf org display
```

#### Solution B: Authenticate using auth URL
```bash
# If you have an auth URL
sf org login sfdx-url --sfdx-url-file path/to/auth.txt --alias myorg
```

#### Solution C: Install Salesforce CLI
```bash
# Install globally
npm install -g @salesforce/cli

# Verify installation
sf version
```

#### Solution D: Refresh expired session
```bash
# Re-authenticate
sf org login web --alias myorg

# Or logout and login again
sf org logout --target-org myorg
sf org login web --alias myorg
```

---

### Issue 2: "No template files found"

**Symptoms:**
```
No template files found in data/sdocsTemplates/
Please add S-Docs template JSON files to this directory.
```

**Causes:**
- Directory doesn't exist
- No .json files in directory
- Wrong directory structure

**Solutions:**

#### Solution A: Verify directory exists
```bash
# Check if directory exists
ls -la data/sdocsTemplates/

# Create if missing
mkdir -p data/sdocsTemplates
```

#### Solution B: Add template files
```bash
# Navigate to templates directory
cd data/sdocsTemplates

# Create a sample template
cat > sample-template.json << 'EOF'
{
  "Name": "Sample Template",
  "SDOC__Template_Type__c": "Document",
  "SDOC__Description__c": "Sample S-Docs template",
  "SDOC__Template_Status__c": "Active",
  "SDOC__Object_API_Name__c": "Account",
  "SDOC__File_Type__c": "PDF"
}
EOF

# Verify file was created
ls -la
```

#### Solution C: Check file extensions
```bash
# Files must end with .json
mv template.txt template.json

# Verify
ls -la data/sdocsTemplates/*.json
```

---

### Issue 3: "JSON parse error"

**Symptoms:**
```
✗ Error upserting template: Unexpected token...
SyntaxError: Unexpected token } in JSON
```

**Causes:**
- Invalid JSON syntax
- Missing commas
- Extra commas
- Missing quotes

**Solutions:**

#### Solution A: Validate JSON syntax
```bash
# Use Python to validate JSON
python3 -m json.tool data/sdocsTemplates/your-template.json

# Use Node.js to validate
node -e "console.log(JSON.parse(require('fs').readFileSync('data/sdocsTemplates/your-template.json', 'utf8')))"
```

#### Solution B: Common JSON mistakes

**Missing comma:**
```json
❌ Wrong:
{
  "Name": "Test"
  "Type": "Document"
}

✅ Correct:
{
  "Name": "Test",
  "Type": "Document"
}
```

**Extra comma:**
```json
❌ Wrong:
{
  "Name": "Test",
  "Type": "Document",
}

✅ Correct:
{
  "Name": "Test",
  "Type": "Document"
}
```

**Missing quotes:**
```json
❌ Wrong:
{
  Name: "Test",
  "Type": "Document"
}

✅ Correct:
{
  "Name": "Test",
  "Type": "Document"
}
```

#### Solution C: Use a JSON validator
- Online: https://jsonlint.com/
- VS Code: Install "JSON" extension
- Command line: `jq` tool

---

### Issue 4: "npm command not found"

**Symptoms:**
```bash
npm run sdocs:upsertAll
-bash: npm: command not found
```

**Causes:**
- Node.js/npm not installed
- Not in PATH

**Solutions:**

#### Solution A: Install Node.js
```bash
# Check if installed
node --version

# Install on Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install on Mac
brew install node

# Verify installation
node --version
npm --version
```

#### Solution B: Fix PATH
```bash
# Find npm location
which npm

# Add to PATH (in ~/.bashrc or ~/.zshrc)
export PATH="/usr/local/bin:$PATH"

# Reload shell
source ~/.bashrc
```

---

### Issue 5: "Permission denied" when running scripts

**Symptoms:**
```bash
npm run sdocs:upsertAll
EACCES: permission denied
```

**Causes:**
- Script not executable
- Insufficient permissions
- Wrong ownership

**Solutions:**

#### Solution A: Make script executable
```bash
# Add execute permission
chmod +x scripts/sdocs-upserter.js

# Verify
ls -la scripts/sdocs-upserter.js
```

#### Solution B: Run with node explicitly
```bash
# Instead of direct execution
node scripts/sdocs-upserter.js
```

#### Solution C: Fix ownership
```bash
# Fix file ownership (if needed)
sudo chown -R $USER:$USER .

# Fix permissions
chmod 755 scripts/*.js
```

---

### Issue 6: GitHub Actions workflow fails

**Symptoms:**
- Workflow shows red X in GitHub
- "Authentication failed" error
- "Command not found" error

**Causes:**
- Missing secrets
- Invalid auth URL
- Incorrect workflow syntax

**Solutions:**

#### Solution A: Verify GitHub Secrets
1. Go to repository Settings
2. Click "Secrets and variables" → "Actions"
3. Verify these secrets exist:
   - `SFDX_AUTH_URL`
   - `SFDX_DEVHUB_AUTH_URL` (for scratch orgs)

#### Solution B: Generate auth URL
```bash
# Display auth URL
sf org display --verbose --json --target-org myorg

# Look for "sfdxAuthUrl" in output
# Copy entire force://... URL
# Paste into GitHub secret
```

#### Solution C: Check workflow logs
1. Go to repository → Actions tab
2. Click failed workflow run
3. Click failed job
4. Read error messages
5. Fix issues based on error

#### Solution D: Test workflow locally
```bash
# Install act (GitHub Actions local runner)
brew install act  # Mac
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow locally
act -j deploy
```

---

### Issue 7: "Template must have a Name field"

**Symptoms:**
```
✗ Error upserting template: Template must have a Name field
```

**Causes:**
- Missing "Name" field in template JSON
- "Name" field is empty
- Wrong field name (case-sensitive)

**Solutions:**

#### Solution A: Add Name field
```json
{
  "Name": "Your Template Name",
  "SDOC__Template_Type__c": "Document",
  ...
}
```

#### Solution B: Check case sensitivity
```json
❌ Wrong:
{
  "name": "Test",  // lowercase
  "NAME": "Test"   // uppercase
}

✅ Correct:
{
  "Name": "Test"   // Proper case
}
```

#### Solution C: Ensure Name has value
```json
❌ Wrong:
{
  "Name": "",      // Empty
  "Name": null     // Null
}

✅ Correct:
{
  "Name": "Test Template"  // Has value
}
```

---

### Issue 8: "Module not found" errors

**Symptoms:**
```
Error: Cannot find module 'jsforce'
Error: Cannot find module 'dotenv'
```

**Causes:**
- Dependencies not installed
- node_modules directory missing
- Wrong directory

**Solutions:**

#### Solution A: Install dependencies
```bash
# Clean install
rm -rf node_modules package-lock.json
npm install

# Or use ci for clean install
npm ci
```

#### Solution B: Verify package.json exists
```bash
# Check if in correct directory
ls -la package.json

# If not found, navigate to project root
cd /path/to/liquibase-changes
```

#### Solution C: Check Node.js version
```bash
# Check version
node --version

# Should be v16 or higher
# Update if needed
nvm install 18
nvm use 18
```

---

### Issue 9: S-Docs package not found in org

**Symptoms:**
```
Error: Invalid field: SDOC__Template_Type__c
Object type 'SDOC__Template__c' is not supported
```

**Causes:**
- S-Docs package not installed in target org
- Wrong org authenticated
- Package not configured

**Solutions:**

#### Solution A: Verify S-Docs installation
```bash
# List installed packages
sf package installed list --target-org myorg

# Look for S-Docs in output
```

#### Solution B: Install S-Docs package
1. Go to Salesforce AppExchange
2. Search for "S-Docs"
3. Install in target org
4. Wait for installation to complete
5. Try deployment again

#### Solution C: Verify correct org
```bash
# Check which org you're connected to
sf org display

# Switch to correct org if needed
sf config set target-org correct-org-alias
```

---

### Issue 10: Deployment succeeds but templates not visible

**Symptoms:**
- Script reports success
- No errors shown
- Templates not visible in Salesforce UI

**Causes:**
- Permission issues
- Wrong object
- Template status inactive

**Solutions:**

#### Solution A: Check permissions
```bash
# Assign S-Docs permission set
sf org assign permset --name SDOC_Admin --target-org myorg

# Or assign in UI:
# Setup → Users → [Your User] → Permission Set Assignments
```

#### Solution B: Verify in Salesforce
1. Login to Salesforce
2. Navigate to App Launcher
3. Search for "S-Docs"
4. Click "Templates"
5. Check if templates exist

#### Solution C: Check template status
```json
// Ensure template is Active
{
  "Name": "Test",
  "SDOC__Template_Status__c": "Active",  // Not "Inactive"
  ...
}
```

---

## 🔧 Advanced Troubleshooting

### Enable Debug Mode

Create `.env` file in project root:
```bash
DEBUG=true
NODE_ENV=development
```

Run with debug output:
```bash
DEBUG=true npm run sdocs:upsertAll
```

### Check File Permissions

```bash
# List all files with permissions
ls -laR

# Fix permissions if needed
chmod 644 *.json *.md
chmod 755 scripts/*.js
chmod 755 .github/workflows/*.yml
```

### Verify Git Configuration

```bash
# Check git status
git status

# Check remote
git remote -v

# Check branch
git branch

# Pull latest changes
git pull origin main
```

### Test Network Connectivity

```bash
# Test Salesforce connectivity
curl -I https://login.salesforce.com

# Test npm registry
curl -I https://registry.npmjs.org

# Test GitHub
curl -I https://github.com
```

### Clean and Rebuild

```bash
# Clean everything
rm -rf node_modules package-lock.json
npm cache clean --force

# Reinstall
npm install

# Test
npm run sdocs:upsertAll
```

---

## 📊 Diagnostic Script

Create `diagnose.sh` for automated diagnostics:

```bash
#!/bin/bash

echo "=== System Diagnostics ==="
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "SF CLI: $(sf version 2>&1 | head -1)"
echo ""

echo "=== Directory Structure ==="
echo "Current dir: $(pwd)"
ls -la
echo ""

echo "=== Template Files ==="
ls -la data/sdocsTemplates/ 2>/dev/null || echo "Directory not found"
echo ""

echo "=== Salesforce Orgs ==="
sf org list 2>&1
echo ""

echo "=== npm Scripts ==="
npm run 2>&1 | grep -A 20 "available via"
echo ""

echo "=== Git Status ==="
git status
echo ""

echo "Diagnostics complete!"
```

Run it:
```bash
chmod +x diagnose.sh
./diagnose.sh
```

---

## 📞 Getting Help

### Information to Provide

When asking for help, include:

1. **Error message** (full text)
2. **Command you ran**
3. **Output of diagnostic commands**
4. **Environment details** (OS, Node version, etc.)
5. **What you've tried**

### Example Help Request

```
Subject: S-Docs deployment failing with authentication error

Environment:
- OS: Ubuntu 20.04
- Node.js: v18.0.0
- SF CLI: @salesforce/cli/2.0.0

Command run:
npm run sdocs:upsertAll

Error:
✗ Fatal error: Unable to detect connected Salesforce org

What I tried:
1. Ran sf org login web --alias myorg
2. Verified with sf org display
3. Still getting error

Output of sf org display:
[paste output here]

Output of sf version:
[paste output here]
```

---

## 📚 Additional Resources

- [Salesforce CLI Troubleshooting](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_troubleshoot.htm)
- [Node.js Troubleshooting](https://nodejs.org/en/docs/guides/)
- [GitHub Actions Debugging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows)
- [S-Docs Documentation](https://www.s-docs.com/documentation/)

---

## ✅ Prevention Checklist

Avoid issues by following this checklist:

- [ ] Always work in project root directory
- [ ] Run `npm install` after cloning
- [ ] Authenticate before deploying
- [ ] Validate JSON before committing
- [ ] Test locally before pushing
- [ ] Check workflow logs after deployment
- [ ] Keep Salesforce CLI updated
- [ ] Keep Node.js updated
- [ ] Document custom changes
- [ ] Use version control

---

**Still having issues?** 
1. Check [SETUP_GUIDE.md](SETUP_GUIDE.md)
2. Review [ARCHITECTURE.md](ARCHITECTURE.md)
3. Contact SF DevOps team
