---
name: demo-prompts
description: "Demo prompts for Cortex Code presentation. Use when: running the 5-7 min demo. Triggers: demo, presentation, demo prompts."
---

# Cortex Code Demo Prompts

Run these prompts in order for a 5-7 minute demo.

## Demo List

| Demo | Persona | Prompt |
|------|---------|--------|
| 1 | Business Analyst | Show me top 10 customers by total spend |
| 2 | Data Engineer | Show me what a dbt model for customer churn risk would look like |
| 3 | Data Engineer | Explain the existing CLV dbt model |
| 4 | Business User | Start the Streamlit dashboard from /Users/ddesai/Apps/automated-intelligence/streamlit-dashboard |
| 5 | Executive | What was our total revenue last month? |
| 6 | Customer Success Manager | Who are our at-risk customers? |
| 7 | Developer | Create a Streamlit app that shows customer churn risk |

## Instructions

1. **Before executing each demo**, ALWAYS display the persona introduction:
   > **As a/an [persona], I can ask: "[prompt]"**

2. **After completing each demo**, ALWAYS show the full demo list table again with the **next demo highlighted in bold** using `**` markers around that row's content. Example after completing demo 1:

   | Demo | Persona | Prompt |
   |------|---------|--------|
   | ~~1~~ | ~~Business Analyst~~ | ~~Show me top 10 customers by total spend~~ |
   | **2** | **Data Engineer** | **Show me what a dbt model for customer churn risk would look like** |
   | 3 | Data Engineer | Explain the existing CLV dbt model |
   | 4 | Business User | Start the Streamlit dashboard... |
   | 5 | Executive | What was our total revenue last month? |
   | 6 | Customer Success Manager | Who are our at-risk customers? |
   | 7 | Developer | Create a Streamlit app that shows customer churn risk |

3. Use ~~strikethrough~~ for completed demos and **bold** for the next demo

4. When user says "demo 1", "demo 2", etc., run that specific prompt

5. When user says "next demo" or "next", run the next prompt in sequence

6. Keep responses concise and demo-friendly
