# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias QuestionnaireCopilot.Repo
alias QuestionnaireCopilot.Vault.QAPair
alias QuestionnaireCopilot.Questionnaires.{Questionnaire, QuestionnaireItem}

# Clear existing data
Repo.delete_all(QuestionnaireItem)
Repo.delete_all(Questionnaire)
Repo.delete_all(QAPair)

# --- Q&A Vault ---

qa_pairs = [
  %{
    question: "Do you encrypt data at rest?",
    answer: "Yes. All data at rest is encrypted using AES-256. Database volumes use full-disk encryption, and application-level encryption is applied to sensitive fields such as credentials and PII.",
    tags: ["encryption", "data-protection"],
    source: "SOC2 2024"
  },
  %{
    question: "Do you encrypt data in transit?",
    answer: "Yes. All data in transit is encrypted using TLS 1.2 or higher. Internal service-to-service communication also uses mTLS. We enforce HSTS and do not support legacy protocols such as SSL or TLS 1.0/1.1.",
    tags: ["encryption", "network-security"],
    source: "SOC2 2024"
  },
  %{
    question: "What is your password policy?",
    answer: "We enforce a minimum of 12 characters with complexity requirements (uppercase, lowercase, number, special character). Passwords are hashed using bcrypt with a work factor of 12. We support and encourage MFA for all accounts.",
    tags: ["authentication", "access-control"],
    source: "ISO 27001 Audit 2024"
  },
  %{
    question: "Do you support multi-factor authentication (MFA)?",
    answer: "Yes. MFA is supported and enforced for all employee accounts. We support TOTP-based authenticator apps and hardware security keys (FIDO2/WebAuthn). SMS-based MFA is not offered due to SIM-swapping risks.",
    tags: ["authentication", "access-control"],
    source: "SOC2 2024"
  },
  %{
    question: "How do you handle incident response?",
    answer: "We maintain a documented incident response plan that is reviewed and tested annually. Our process follows NIST SP 800-61 guidelines with defined roles, escalation paths, and communication procedures. Incidents are classified by severity (P1-P4) with corresponding SLAs. Post-incident reviews are conducted within 48 hours of resolution.",
    tags: ["incident-response", "compliance"],
    source: "Incident Response Plan v3.2"
  },
  %{
    question: "What is your data retention policy?",
    answer: "Customer data is retained for the duration of the contract plus 30 days. Upon termination, data is securely deleted within 30 days and a certificate of destruction is provided upon request. Backups are purged within 90 days of deletion. Audit logs are retained for 1 year.",
    tags: ["data-retention", "data-protection"],
    source: "Data Governance Policy"
  },
  %{
    question: "Do you perform regular penetration testing?",
    answer: "Yes. We engage an independent third-party firm to conduct penetration testing at least annually, covering both external and internal attack surfaces. Critical and high findings are remediated within 30 days. Reports are available to customers under NDA.",
    tags: ["vulnerability-management", "compliance"],
    source: "Pentest Report 2024"
  },
  %{
    question: "How do you manage access control?",
    answer: "We follow the principle of least privilege. Access is role-based (RBAC) and reviewed quarterly. All access requires manager approval and is provisioned through our identity provider (Okta). Privileged access requires additional approval and is logged and monitored. Offboarding triggers immediate revocation of all access.",
    tags: ["access-control", "identity-management"],
    source: "Access Control Policy"
  },
  %{
    question: "Do you have a SOC 2 report?",
    answer: "Yes. We maintain a SOC 2 Type II report covering the Security, Availability, and Confidentiality trust service criteria. Our most recent report covers the 12-month period ending December 2024. A copy is available under NDA upon request.",
    tags: ["compliance", "audit"],
    source: "SOC2 2024"
  },
  %{
    question: "Where is customer data stored?",
    answer: "Customer data is stored in AWS US regions (us-east-1 and us-west-2). We do not store or process customer data outside the United States unless explicitly requested. All storage services are configured with encryption at rest enabled by default.",
    tags: ["data-protection", "infrastructure"],
    source: "Infrastructure Documentation"
  },
  %{
    question: "How do you handle vulnerability management?",
    answer: "We run automated vulnerability scans weekly across all infrastructure and application components. Critical vulnerabilities are patched within 24 hours, high within 7 days, medium within 30 days. We subscribe to relevant CVE feeds and vendor advisories for proactive monitoring.",
    tags: ["vulnerability-management", "security-operations"],
    source: "Vulnerability Management Policy"
  },
  %{
    question: "Do you have a business continuity plan?",
    answer: "Yes. Our BCP covers disaster recovery, data backup, and operational continuity. RPO is 1 hour and RTO is 4 hours for critical systems. The plan is tested annually through tabletop exercises and failover drills. Backups are replicated to a secondary region.",
    tags: ["business-continuity", "disaster-recovery"],
    source: "BCP v2.1"
  },
  %{
    question: "What logging and monitoring do you have in place?",
    answer: "We centralize logs from all systems using a SIEM platform. This includes application logs, infrastructure logs, authentication events, and network flow data. Alerts are configured for anomalous activity and security events. Logs are retained for 12 months and are immutable.",
    tags: ["logging", "security-operations", "monitoring"],
    source: "Security Operations Runbook"
  },
  %{
    question: "Do you conduct security awareness training?",
    answer: "Yes. All employees complete security awareness training upon onboarding and annually thereafter. Training covers phishing, social engineering, data handling, and incident reporting. We also conduct quarterly phishing simulations with targeted follow-up training for employees who fail.",
    tags: ["training", "compliance"],
    source: "HR Security Policy"
  },
  %{
    question: "How do you handle third-party risk?",
    answer: "All vendors with access to customer data undergo a security assessment before onboarding. Critical vendors are reassessed annually. We require SOC 2 reports or equivalent certifications, review their security posture, and include data protection clauses in all contracts.",
    tags: ["vendor-management", "compliance", "third-party-risk"],
    source: "Vendor Risk Management Policy"
  },
  %{
    question: "Do you have a data classification policy?",
    answer: "Yes. Data is classified into four tiers: Public, Internal, Confidential, and Restricted. Customer data is classified as Confidential or Restricted depending on sensitivity. Each tier has defined handling, storage, transmission, and disposal requirements.",
    tags: ["data-protection", "compliance"],
    source: "Data Classification Policy"
  }
]

inserted_pairs =
  Enum.map(qa_pairs, fn attrs ->
    %QAPair{}
    |> QAPair.changeset(attrs)
    |> Repo.insert!()
  end)

IO.puts("Seeded #{length(inserted_pairs)} Q&A pairs")

# --- Sample Questionnaire ---

{:ok, questionnaire} =
  %Questionnaire{}
  |> Questionnaire.changeset(%{name: "Acme Corp Security Assessment Q1 2025"})
  |> Repo.insert()

questions = [
  "Does your organization encrypt sensitive data at rest?",
  "How is data protected during transmission between systems?",
  "What is your organization's password complexity policy?",
  "Is multi-factor authentication required for system access?",
  "Describe your incident response process.",
  "How long do you retain customer data after contract termination?",
  "When was your last third-party penetration test conducted?",
  "How do you enforce the principle of least privilege?",
  "Do you hold a current SOC 2 Type II certification?",
  "In which geographic regions is customer data stored and processed?",
  "What is your process for patching critical vulnerabilities?",
  "Do you have a documented business continuity and disaster recovery plan?",
  "What SIEM or log management solution do you use?",
  "How often do employees receive security awareness training?",
  "How do you assess the security posture of your subprocessors and vendors?"
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

items =
  questions
  |> Enum.with_index(1)
  |> Enum.map(fn {q, pos} ->
    %{
      original_question: q,
      position: pos,
      status: :unmatched,
      questionnaire_id: questionnaire.id,
      inserted_at: now,
      updated_at: now
    }
  end)

Repo.insert_all(QuestionnaireItem, items)

IO.puts("Seeded questionnaire with #{length(questions)} questions")
