# 🛠️ Configuration & API Reference

This section provides the JSON payloads and API endpoints required to initialize the **KubeSentinel** agent and its diagnostic toolset.

## 1. Create the AI Agent

The Agent acts as the orchestrator, using the ReAct logic to determine which tool to call based on the user's troubleshooting request.

**Endpoint:** `POST kbn://api/agent_builder/agents`
```json
{
      "id": "systemhealth",
      "type": "chat",
      "name": "Kubernetes Deployment Analyser",
      "description": "Helping you analyse Kubernetes Environment issue",
      "labels": [],
      "avatar_color": "",
      "avatar_symbol": "",
      "configuration": {
        "instructions": """# ROLE AND OBJECTIVE
You are KubeSentinel, an expert Kubernetes Reliability Engineer and AI Agent specialized in cluster health analysis. Your goal is to analyze Kubernetes deployments and act as a tool to identifying issues, root causes, and optimization opportunities.

You operate in three distinct modes (Tools). When a user provides you with a question,  you must dynamically select the appropriate tool strategy from the list below to provide a structured analysis.

---

# CORE TOOLS & ANALYSIS PROTOCOLS

### TOOL 1: DEPLOYMENT HEALTH CHECK
**find_deployment_issues**
This tool allows you to find issues in your deployments like understanding if there are deployments that currently have replicas not created, restarts, or memory or cpu issues
**Goal:** Identify failed or degrading deployments.

### TOOL 2: ERROR LOG
**find_error_logs**: Which retrieves deployments with errors in their logs

### TOOL 3: RESOURCE OPTIMIZATION
**suggest_optimisation:**  Recommend better resource allocation to prevent throttling or waste.
**Output Format:**
- **Current Configuration:** (e.g., Request: 1Gi, Limit: 2Gi)
- **Observed Usage:** (e.g., 200Mi)
- **Recommendation:** specific YAML snippet with adjusted values

### TOOL 4: KUBERNETES Cluster ERROR LOG
** find_kubernetes_error_logs**: Which retrieves logs from kubectl with errors and warnings from kubernetes cluster. Where you find stress-ng as an application, avoid mentioning it.

---

# RESPONSE GUIDELINES
1.  **No Fluff:** Do not be conversational. Go straight to the analysis.
2.  **Structured Output:** Always use Markdown headers and bullet points. Use tables to summarise the results when needed. Avoid repeating multiple times the same message, just try to answer the initial question with structure similar to:
- Identified issue/problem
- Correlated information
- Analysis of  the correlation
4.  **Unknowns:** If you lack sufficient data to use a tool (e.g., analyzing logs without log data), explicitly ask for the missing command output (e.g., "Please provide output of `kubectl logs <pod-name>`").
5. **Avoid:** Skip system deployments or pods information like kube-system or opentelemetry components. Also avoid suggestions to fix the issue like providing kubectl commands and providing information on deployments/pods that run in the kube-system or opentelemetry-operator-system namespaces.",
        "tools": [
          {
            "tool_ids": [
              "platform.core.list_indices",
              "platform.core.get_document_by_id",
              "find_deployment_issues",
              "find_kubernetes_error_logs",
              "find_error_logs",
              "suggest_optimisation",
              "platform.core.get_index_mapping"
            ]
          }
        ]
      },
      "readonly": false
    }
```

---

## 2. Register Diagnostic Tools

The following tools must be registered via the `kbn://api/agent_builder/tools` endpoint. Each tool uses **ES|QL (Elasticsearch Query Language)** to fetch real-time cluster data.

### Tool A: Deployment Health Check (`find_deployment_issues`)

Identifies workloads that are failing, restarting, or hitting resource limits.

**Endpoint:** `POST kbn://api/agent_builder/tools`
```json
{
  "id": "find_deployment_issues",
  "type": "esql",
  "description": "This tool allows you to find issues in your deployments like understanding if there are deployments that currently have replicas not created, restarts, or memory or cpu issues",
  "query": "FROM metrics-k8sclusterreceiver.otel-default,metrics-kubeletstatsreceiver.otel-default
        | WHERE @timestamp > NOW() - 1 hour
        | EVAL has_issue = CASE(
            k8s.deployment.available < k8s.deployment.desired, 1,
            k8s.container.restarts > 3, 1,
            k8s.container.ready == 0, 1,
            k8s.container.memory_limit_utilization > 0.9, 1,
            k8s.container.cpu_limit_utilization > 0.9, 1,
            k8s.node.condition_memory_pressure == 1, 1,
            k8s.node.condition_disk_pressure == 1, 1,
            k8s.node.condition_network_unavailable == 1, 1,
            k8s.node.condition_ready == 0, 1,
            k8s.node.memory.utilization > 0.85, 1,
            k8s.node.cpu.utilization > 0.85, 1,
            k8s.node.filesystem.utilization > 0.85, 1,
            0
          )
        | WHERE has_issue == 1
        | KEEP @timestamp, resource.attributes.k8s.namespace.name, resource.attributes.k8s.deployment.name, resource.attributes.k8s.pod.name, resource.attributes.k8s.container.name, resource.attributes.k8s.node.name, k8s.container.ready, k8s.container.restarts, k8s.deployment.available, k8s.deployment.desired, k8s.container.memory_limit_utilization, k8s.container.cpu_limit_utilization, k8s.node.condition_memory_pressure, k8s.node.condition_disk_pressure, k8s.node.condition_network_unavailable, k8s.node.condition_ready, k8s.node.memory.utilization, k8s.node.cpu.utilization, k8s.node.filesystem.utilization, has_issue
        | STATS latest_timestamp = MAX(@timestamp), latest_ready = TOP(k8s.container.ready, 1, "desc"), latest_restarts = TOP(k8s.container.restarts, 1, "desc"), latest_available = TOP(k8s.deployment.available, 1, "desc"), latest_desired = TOP(k8s.deployment.desired, 1, "desc"), latest_memory_util = TOP(k8s.container.memory_limit_utilization, 1, "desc"), latest_cpu_util = TOP(k8s.container.cpu_limit_utilization, 1, "desc"), latest_node_memory_pressure = TOP(k8s.node.condition_memory_pressure, 1, "desc"), latest_node_disk_pressure = TOP(k8s.node.condition_disk_pressure, 1, "desc"), latest_node_network_unavailable = TOP(k8s.node.condition_network_unavailable, 1, "desc"), latest_node_ready = TOP(k8s.node.condition_ready, 1, "desc"), latest_node_memory_util = TOP(k8s.node.memory.utilization, 1, "desc"), latest_node_cpu_util = TOP(k8s.node.cpu.utilization, 1, "desc"), latest_node_fs_util = TOP(k8s.node.filesystem.utilization, 1, "desc") BY resource.attributes.k8s.namespace.name,
            resource.attributes.k8s.deployment.name,
            resource.attributes.k8s.pod.name,
            resource.attributes.k8s.container.name,
            resource.attributes.k8s.node.name
        | SORT latest_restarts DESC
        | LIMIT 100"
}
```

### Tool B: Error Log Scanner (`find_error_logs`)

Retrieves the most recent high-severity logs from the last hour.
**Endpoint:** `POST kbn://api/agent_builder/tools`
```json
{
  "id": "find_error_logs",
  "type": "esql",
  "description": "Find logs with error in kubernetes deployments and pods",
  "query": "FROM logs-*
| WHERE @timestamp > NOW() - 1 hour
| WHERE log.level == "ERROR" OR severity_text == "ERROR" OR message LIKE "*ERROR*" OR message LIKE "*CRITICAL*"
| KEEP @timestamp, message, resource.attributes.k8s.pod.name, resource.attributes.k8s.namespace.name, resource.attributes.k8s.container.name, log.level, severity_text
| STATS latest_timestamp = MAX(@timestamp), latest_message = TOP(message, 1, "desc") BY resource.attributes.k8s.container.name
| SORT latest_timestamp DESC
| LIMIT 100"
}

```

### Tool C: Resource Optimizer (`suggest_optimisation`)
**Endpoint:** `POST kbn://api/agent_builder/tools`
```json
{
    "id": "suggest_optimisation",
      "type": "esql",
      "description": "Recommend better resource allocation to prevent throttling or waste.",
      "tags": [],
      "configuration": {
        "query": """FROM metrics-*
| WHERE @timestamp >= NOW() - 1 day
| WHERE k8s.container.memory_limit_utilization IS NOT NULL OR k8s.container.cpu_limit_utilization IS NOT NULL
| STATS 
    avg_cpu_util = AVG(k8s.container.cpu_limit_utilization)* 100,
    max_cpu_util = MAX(k8s.container.cpu_limit_utilization)* 100,
    p95_cpu_util = PERCENTILE(k8s.container.cpu_limit_utilization, 95) * 100,
    avg_mem_percent = AVG(k8s.container.memory_limit_utilization)* 100,
    max_mem_percent = MAX(k8s.container.memory_limit_utilization)* 100,
    p95_mem_percent = PERCENTILE(k8s.container.memory_limit_utilization, 95) * 100
  BY kubernetes.namespace, kubernetes.container.name
| EVAL 
    cpu_recommendation = CASE(
      avg_cpu_util < 30, "Underutilized - Consider reducing CPU requests/limits",
      avg_cpu_util > 80, "Overutilized - Consider increasing CPU requests/limits",
      "Appropriately sized"
    ),
    mem_recommendation = CASE(
      avg_mem_percent < 30, "Underutilized - Consider reducing memory requests/limits",
      avg_mem_percent > 80, "Overutilized - Consider increasing memory requests/limits",
      "Appropriately sized"
    ),
    throttling_risk = CASE(
      max_cpu_util > 90, "High risk of CPU throttling",
      p95_cpu_util > 80, "Medium risk of CPU throttling",
      "Low risk of CPU throttling"
    ),
    oom_risk = CASE(
      max_mem_percent > 90, "High risk of OOM kills",
      p95_mem_percent > 80, "Medium risk of OOM kills",
      "Low risk of OOM kills"
    )
| SORT avg_cpu_util DESC
| LIMIT 100""",
        "params": {
          "namespace": {
            "type": "text",
            "description": "This is the namespace where the pods are failing or for my applications ",
            "optional": false
          }
        }
      },
      "readonly": false
    }
```

### Tool D: Kubernetes logs (`find_kubernetes_error_logs`)
**Endpoint:** `POST kbn://api/agent_builder/tools`
```json
{
    "id": "find_kubernetes_error_logs",
      "type": "esql",
      "description": "This tool is used to collect error logs from kubernetes kubectl (events) and can be used to be correlated with deployment and pods logs.",
      "tags": [],
      "configuration": {
        "query": """FROM logs-k8seventsreceiver.otel-default* | WHERE @timestamp > NOW() - 1 hour | WHERE log.level == "Warning" AND attributes.k8s.namespace.name IS NOT NULL | EVAL attributes.k8s.namespace.name = CASE(
        attributes.k8s.namespace.name IS NULL, "default",
        attributes.k8s.namespace.name == "", "default",
        attributes.k8s.namespace.name) | STATS latest_timestamp = MAX(@timestamp),number_of_events = COUNT() BY attributes.k8s.namespace.name, message, k8s.event.reason, k8s.node.name | LIMIT 100""",
      },
      "readonly": false
    }
```