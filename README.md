# Purview
Microsoft Purview

# Microsoft Purview Compliance Administration Scripts

This repository contains scripts designed for **compliance administrators** who manage users, permissions, policies, and configurations within the **Microsoft Purview Admin Center** ([purview.microsoft.com](https://purview.microsoft.com)).

## Purpose

The scripts included in this repository aim to help administrators:

- List and manage **RBAC roles** in Purview.
- Enumerate users and their assigned roles or role groups.
- Assist with policy configuration and compliance management.
- Automate routine administrative tasks in the Purview portal.

### Note on Purview PowerShell Permissions

Microsoft Purview currently **does not have its own dedicated PowerShell module** that interacts exclusively with the Purview portal. When performing role or permission queries via PowerShell, the calls are handled through **Exchange Online** and the **Security & Compliance** (Purview Compliance) PowerShell endpoints.  

This is why scripts that examine roles and permissions typically require both:

- `Connect-ExchangeOnline`
- `Connect-IPPSSession` (Security & Compliance / Purview PowerShell)

You *can* follow the principle of least privilege by using a custom Exchange RBAC role such as **View-Only Configuration** or **View-Only Role Management**, but **these will not provide a complete view of all Purview role groups or assigned users**.  

To retrieve **all** role assignments visible in the Microsoft Purview portal, the account must have sufficient permissions in **both** PowerShell modules, not just within the Exchange Admin Center.  


## Getting Started

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/welkasworld/purview.git
