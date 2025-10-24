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