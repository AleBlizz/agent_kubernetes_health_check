# Kubernetes Troubleshooting Demos: Agent Builder & Workflows

This repository showcases two innovative approaches to automated Kubernetes operations: **Agentic AI** and **Event-Driven Workflows**. These demos replicate real-world microservice failures to demonstrate how automation can effectively detect and resolve infrastructure issues.

## 🛠️ E-commerce Simulation - Project Overview

The demos are built around a simulated microservice architecture featuring two interconnected services:

1. **Cart Service:** Handles user requests but relies on the Payment Service.
2. **Payment Service:** Intentionally designed to simulate **Out-Of-Memory (OOM)** errors.

### The Failure Cycle

* **Trigger:** The Payment Service encounters a simulated memory leak.
* **Crash:** Kubernetes terminates the Payment Service pod (OOMKilled).
* **Impact:** The Cart Service loses connectivity, generating `ERROR` logs.
* **Recovery:** Kubernetes restarts the Payment Service pod, temporarily restoring functionality until the next failure.

---

### 🤖 Demo 1: AI Agent Builder

This demo highlights an intelligent assistant capable of autonomously diagnosing Kubernetes environments.

Unlike static scripts, the Agent employs "Reasoning and Acting" to investigate the cluster using three specialized tools (detailed in the Tools Description page).

* **How it works:** You provide a natural language query (e.g., *"Why is the cart service failing?"*).
* **Action:** The Agent inspects the cluster, identifies the restarting Payment Service pod, and correlates the OOM event with the Cart Service errors.
* **Benefit:** Reduces the cognitive load on SREs by automatically linking logs and events.

Additional services can be introduced to simulate scenarios like resource underutilization or overprovisioning. These scenarios demonstrate dynamic resource adjustments, such as resizing memory requests based on actual usage patterns.

*The Agent also includes a tool that analyzes resource usage and recommends optimizations, helping identify overprovisioned deployments. Tools are described in the tools.md which also provide a list of API calls to deploy the agent and the tools on your cluster*


## ⚡ Demo 2: Remediation Workflows

This demo demonstrates a deterministic, event-driven approach to infrastructure management using automated workflows.

### Workflow Steps:

1. **Detection:** A monitoring alert triggers when resource consumption exceeds predefined thresholds.
2. **Collection:** The workflow identifies the specific deployment(s) responsible for high memory usage.
3. **Remediation:** The system executes remediation scripts on the cluster to adjust memory limits, preventing crashes.

In this demo, a dedicated service within the *`frontend-ecommerce`* deployment simulates high memory usage, triggering the alerting logic. The remediation service, deployed as *`cluster-scaler-api`*, exposes a REST API that accepts a list of deployment names. This service is defined in the *`cluster-manager`* template, which includes RBAC configurations and a LoadBalancer service to enable cluster-wide operations.

Workflow is described in the *`workflow.yaml`* file.

### Demo 3: RCA Workflow (Root Cause Analysis)

This workflow runs an automated RCA analysis that aggregates logs, events and metrics, then produces a concise root-cause report.

- Workflow source: Workflows\ library/rca_agent.yaml.
- Purpose: correlate Pod events, OOM/crash logs and service errors to identify the most likely root cause and suggested remediation steps.
- Steps:
  1. Trigger: monitoring alert or manual invocation.
  2. Collection: ingest logs, events and metrics for the affected namespace(s).
  3. Analysis: execute rca_agent to correlate signals and generate findings.
  4. Output: structured RCA report (JSON/YAML) and optional follow-up actions (e.g., annotate incidents, create tickets, or call remediation endpoints).


## Usage

This demo leverages OpenTelemetry and relies on EDOT (Elastic Distribution of OpenTelemetry) for log and metric collection. To get started:

1. Set up an Elastic Cloud Cluster and deploy the EDOT components by following the Kibana tutorial.
2. Copy and paste Workflows in your Kibana
3. Deploy required Agent and tool relying on the provided configuration in the *AgentBuilder* folder
4. Run the script_manage.sh tool to deploy all the needed components
    ```bash
    ./script_manage.sh start
    ```
5. Deploy the required components for the demo remediation
    ```bash
    kubectl apply -f cluster-manager.yaml
    ```
3. Wait for Alerts to be triggered and check your mail :)