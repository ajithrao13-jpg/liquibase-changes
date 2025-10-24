# S-Docs Templates Directory

This directory contains S-Docs template definitions that will be automatically deployed to Salesforce environments.

## 📁 Template Structure

Each template is defined as a JSON file with the following structure:

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

## 📋 Required Fields

- **Name**: Unique name for the template (used as identifier)
- **SDOC__Template_Type__c**: Type of template
  - Options: `Document`, `Email`, `Report`, etc.
- **SDOC__Object_API_Name__c**: Salesforce object API name
  - Examples: `Account`, `Contact`, `Opportunity`, `Contract`

## 📝 Optional Fields

- **SDOC__Description__c**: Description of the template
- **SDOC__Template_Status__c**: Status (`Active`, `Inactive`)
- **SDOC__File_Type__c**: Output file type (`PDF`, `DOCX`, etc.)
- **SDOC__Template_Label__c**: Display label in Salesforce UI
- **SDOC__Header__c**: Header content
- **SDOC__Footer__c**: Footer content
- **SDOC__Body__c**: Template body/content

## 📦 Adding New Templates

1. Create a new `.json` file in this directory
2. Follow the template structure above
3. Ensure the `Name` field is unique
4. Run deployment command:
   ```bash
   npm run sdocs:upsertAll
   ```

## 🎯 Examples

### Example 1: Simple Document Template
```json
{
  "Name": "Invoice Template",
  "SDOC__Template_Type__c": "Document",
  "SDOC__Description__c": "Standard invoice template",
  "SDOC__Template_Status__c": "Active",
  "SDOC__Object_API_Name__c": "Opportunity",
  "SDOC__File_Type__c": "PDF",
  "SDOC__Template_Label__c": "Invoice"
}
```

### Example 2: Email Template
```json
{
  "Name": "Welcome Email",
  "SDOC__Template_Type__c": "Email",
  "SDOC__Description__c": "Welcome email for new customers",
  "SDOC__Template_Status__c": "Active",
  "SDOC__Object_API_Name__c": "Contact",
  "SDOC__Template_Label__c": "Welcome Email"
}
```

### Example 3: Contract Template
```json
{
  "Name": "Service Agreement",
  "SDOC__Template_Type__c": "Document",
  "SDOC__Description__c": "Standard service agreement template",
  "SDOC__Template_Status__c": "Active",
  "SDOC__Object_API_Name__c": "Contract",
  "SDOC__File_Type__c": "DOCX",
  "SDOC__Template_Label__c": "Service Agreement",
  "SDOC__Header__c": "Company Name | Service Agreement",
  "SDOC__Footer__c": "Page {page} of {total_pages}"
}
```

## 🔄 Deployment Process

When you run `npm run sdocs:upsertAll`:

1. Script reads all `.json` files from this directory
2. Validates each template structure
3. Connects to the authenticated Salesforce org
4. Upserts (inserts or updates) each template
5. Provides success/failure feedback

## ✅ Best Practices

1. **Naming Convention**: Use descriptive, unique names
   - ✅ Good: `Contract_ServiceAgreement_v1`
   - ❌ Bad: `Template1`

2. **File Organization**: Group related templates
   - Consider subdirectories for different modules
   - Use consistent file naming

3. **Version Control**: Include all templates in git
   - Track changes to templates over time
   - Document major changes in commit messages

4. **Testing**: Test templates before committing
   - Deploy to sandbox first
   - Verify template renders correctly
   - Check all merge fields work

5. **Documentation**: Document custom fields
   - Add comments explaining non-obvious configurations
   - Document any dependencies

## 🔍 Template Validation

The deployment script validates:
- ✅ File is valid JSON
- ✅ `Name` field exists
- ✅ File extension is `.json`

Additional validation you should do:
- Object API names are correct
- Template type is valid
- All merge fields are available on the object
- Template syntax is correct

## 📊 Current Templates

This directory currently contains:

1. **example-template.json**: Example document template for Account object
2. **contract-template.json**: Standard contract template

Add your templates here following the same structure.

## 🆘 Troubleshooting

**Issue**: Template not deploying
- Check JSON syntax is valid
- Verify `Name` field exists
- Ensure file ends with `.json`

**Issue**: Template deployed but not working
- Check object API name is correct
- Verify S-Docs package is installed
- Check field-level security settings

**Issue**: Duplicate template error
- Change the `Name` field to be unique
- Or delete the existing template in Salesforce first

## 📚 Resources

- [S-Docs Documentation](https://www.s-docs.com/documentation/)
- [Salesforce Object Reference](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/)
- [JSON Syntax Guide](https://www.json.org/)

---

**Need help?** See the main [SETUP_GUIDE.md](../../SETUP_GUIDE.md) for detailed instructions.
