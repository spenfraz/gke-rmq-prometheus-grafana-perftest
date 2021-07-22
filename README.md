# __gke-rmq-prometheus-grafana-perftest__

- ~~TODO: add RabbitMQ alerts and Notification Channel with Alertmanager~~
	- ~~ISSUE: while ```DeadMansSwitch``` alert rule works (w/o labels/{{}} ), using pre-made rabbitmq alerts (https://awesome-prometheus-alerts.grep.to/rules.html) w/labels gives error.~~
		- ~~NOTE: alert rules are currently added to ```helm/prometheus-server/templates/prom-cm.yaml``` (error may be due to helm/go templating conflict(s) --> look at next: https://github.com/helm/charts/issues/966#issuecomment-297903931 & https://prometheus.io/blog/2017/06/21/prometheus-20-alpha3-new-rule-format/#recording-rules-changes & look at ```eks-with-day-two-operations```)~~
- TODO: use Secrets for credentials --> Google Secret Manager in terraform (RabbitMQ and Prometheus-operator (or best practices/support recommends secret management)		
- ~~TODO: add instructions for importing pre-built Grafana dashboard~~
- ~~TODO: add automation for manual steps (helm set values) & possibility of automating grafana <---> prometheus config and dashboard import~~
- ~~1 ERROR to debug:~~ --> **(9-2-2020)UPDATE: No more incidents encountered.**	
-------------------------

# __Functional Summary__

### HA RabbitMQ (+ Perftest) +  Prometheus Operator (metrics based alerting, email notify and visualize metrics) (+ Grafana)
- __Available Dashboards__:
	- Grafana UI
		- imported dashboards
			- Prometheus 2.0 Overview
			- RabbitMQ-Overview
	- Prometheus Management UI
	- RabbitMQ Management UI
###
- __Supported Scenarios__:
	- Perftest (simulate RabbitMQ workload)
	- Failover (delete rabbitmq node/pod during Perftest)

-------------------------

# __Component Breakdown__

### IaC Tooling Components
- **Helm Charts** (```helm/kube-prometheus-stack```, ```helm/rabbitmq-ha```)
	- NOTE: Local Helm chart copies:
		- kube-prometheus-stack ==> https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
		- rabbitmq-ha ==> https://github.com/helm/charts/tree/master/stable/rabbitmq-ha

	
- **Terraform** (```helm_release```,```resource "null_resource" "apply-dashboard-configmap"```,```resource "null_resource" "create_monitoring_ns"```)
	- NOTE: ```json-imported-dashboards-configmap.yaml``` contains the json for:
		- ```RabbitMQ-Overview``` dashboard from: https://grafana.com/api/dashboards/10991/revisions/6/download
		- ```Prometheus 2.0 Overview``` dashboard from: https://grafana.com/api/dashboards/3662/revisions/2/download
		- NOTE: The downloaded json was converted to a one-line string (trimmed whitespace) (both required a "patch", see next NOTE) before pasting into configmap with: https://www.freeformatter.com/json-formatter.html
		- NOTE: a "patch" (replace all "DS_THEMIS" with "DS_PROMETHEUS" (prometheus dashboard) and insert the following block of json) was needed for both dashboard json. https://github.com/grafana/grafana/issues/10786#issuecomment-568788499   
				   
				
				(under these lines)
				   
				
				 "templating": {
                       "list": [
					   
			     (insert)
				 
				 {
            		"hide": 0,
            		"label": "datasource",
            		"name": "DS_PROMETHEUS",
            		"options": [],
            		"query": "prometheus",
            		"refresh": 1,
            		"regex": "",
            		"type": "datasource"
          		},

### Cluster-level Components
- **RabbitMQ**
- **Prometheus Operator**
- **Grafana**

-------------------------

# __Functional Validation__

#### NOTE: Use port forward + Web Preview (port 8080) in Google Cloud Shell to view:
- __RabbitMQ Management UI__ (rmq-ha-rabbitmq-ha-0,1,2)
	- ```kubectl port-forward rmq-ha-rabbitmq-ha-0 8080:15672```
	- OR
	- ```kubectl port-forward svc/rmq-ha-rabbitmq-ha 8080:15672```
	    - username:
			- ```admin```
		- password:
			- ```secretpassword```
		- __```After Step 3)``` CONFIRM__ RabbitMQ management ui available
		- __```After Step 8)``` WATCH__ RabbitMQ cluster metrics during Stress Test
		- __```After Step 8)``` WATCH__ RabbitMQ cluster metrics during Failover Test
		- __```For Additional Scenarios``` USE__ (upload via ui) RabbitMQ export/import Cluster Definition
###	
- __Metrics from RabbitMQ Pods__ (rmq-ha-rabbitmq-ha-0,1,2)
	- ```kubectl port-forward rmq-ha-rabbitmq-ha-0 8080:15692```
		- __```After Step 3)``` CONFIRM__ RabbitMQ metrics available
###	
- __Prometheus Managment UI__
	- ```kubectl port-forward -n monitoring svc/prometheus-service 8080:8080```
		- __```After Step 3)``` CONFIRM__ RabbitMQ --metrics--> Prometheus
			- Web Preview on port 8080
				- Click Status --> Click Targets
				- Scroll down to bottom of page
				- check for ```kubernetes-pods (3/3 up)``` & check labels column for ```app="rabbitmq-ha"``` and ```stateful_kubernetes_io_pod_name="rmq-rabbitmq-ha-#"```    
###
- __Alertmanager UI__
	- ```kubectl port-forward $(kubectl get po -n monitoring -l app=alertmanager -o name) -n monitoring 8080:9093```
		- __```After Step 3)``` CONFIRM__ Prometheus --alert/notify--> Alertmanager properly configured
###
- __Grafana UI__
	- ```kubectl port-forward -n monitoring $(kubectl get po -n monitoring -l app.kubernetes.io/instance=my-grafana -o name) 8080:3000```
		- username:
			- ```admin```
		- password:
			- ```kubectl get secret my-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode; echo;```
		- __```After Step 3)``` CONFIRM__ Grafana UI
		- __```With Step 6)``` CONFIRM__ Prometheus Data Source in Grafana
		- __```With Step 7)``` CONFIRM__ RabbitMQ metrics show up in Grafana imported dashboard(s)
		- __```With Step 8)``` WATCH__ RabbitMQ metrics during Load Test (Perftest)
		- __```With Step 8)``` WATCH__ RabbitMQ metrics during Failover Test (delete RabbitMQ cluster node/pod)
###
- __Failover Test (during PerfTest)__
	- ```kubectl delete po rmq-ha-rabbitmq-ha-0 --force --grace-period=0```
		- __```After Step 8)``` CONFIRM__ Failover
			- NOTE: failover (all 3 nodes back up) typically takes a few minutes to successfully complete.
				- PROCESS SUMMARY: delete node, grafana shows only 2 nodes (~30s), grafana shows only 1 node (~2-3min), grafana shows 3 nodes (~3-4min)
			- NOTE: occasionally, a node will get 'stuck'/unable to rejoin cluster. 
				- (View RabbitMQ Management UI)
					- ```kubectl port-forward svc/rmq-ha-rabbitmq-ha 8080:15672```
						- At top of page, should see a banner/error message that identifies which node is having problems.
					- Delete node: (in my case it was node 2)
						- ```kubectl delete po rmq-ha-rabbitmq-ha-2 --force --grace-period=0```
					- Grafana shows 3 nodes (~2-4min)

###
-------------------------

# __Process Steps__

#### NOTE: for simplicity use ```Google Cloud Shell``` for following steps.

#### 1) Clone Terraform for GKE Public Cluster => https://github.com/gruntwork-io/terraform-google-gke.git
###
#### 2) Setup Alertmanager Email Notification and Copy over files from this cloned repo directory (```gke-rmq-prometheus-grafana-perftest```) to ```terraform-google-gke``` cloned repo directory
- NOTE: to configure Notification Channel within Alertmanager:
- SOURCE: "How to Set up Gmail Alerts" https://grafana.com/blog/2020/02/25/step-by-step-guide-to-setting-up-prometheus-alertmanager-with-slack-pagerduty-and-gmail/
	- 1) Enable ```2 Step Verification``` for Google Account
	- 2) Create ```App Password```
	- 3) Use ```App Password``` (and email) within Alertmanager config (```helm/kube-prometheus-stack/values.yaml```) (```alertmanager.config # line 143```)
###
- Copy over folder and files from this cloned repo directory (```gke-rmq-prometheus-grafana-perftest```) to ```terraform-google-gke``` cloned repo directory:
	- ```helm/*```
	- ```rabbitmqha-prometheus-alertmanager-grafana.tf```
	- ```json-imported-dasahboards-configmap.yaml```
###
#### 3) Terraform!
- ```terraform init```
- ```terraform apply```
###
#### 4) Port-forward and Web Preview on port 8080
- ```kubectl port-forward -n monitoring $(kubectl get po -n monitoring -l app.kubernetes.io/instance=my-grafana -o name) 8080:3000```
###
#### 5) Login to Grafana UI
- username:
	- ```admin```
- password:
	- ```kubectl get secret my-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode; echo;```
###
#### 6) Confirm (via Grafana UI) Prometheus Datasource configured properly
- Gear icon-->"Configuration" (lower left side vertical)
	- Click "Data Sources"
		- Click "Prometheus-server" (list item (boxed))
			- Click "Test" button (scroll down to bottom)
###
#### 7) Access ```Prometheus 2.0 Overview``` and ```RabbitMQ-Overview``` Dashboards
- Foursquare icon-->"Dashboards" (mid left side vertical)
	- Click "Manage"
		- Click "Prometheus 2.0 Overview" (list item (boxed))
		- OR
		- Click "RabbitMQ-Overview" (list item (boxed))

###
#### 8) Run Perftest pod, simulate RabbitMQ workload (then visualize in Grafana (RabbitMQ-Overview dashboard))
- Create Perftest pod
	- ```kubectl run perftest --image=pivotalrabbitmq/perf-test -- --uri amqp://admin:secretpassword@rmq-ha-rabbitmq-ha:5672```
- Simulate RabbitMQ workload
	- ```kubectl exec -it perftest -- bin/runjava com.rabbitmq.perf.PerfTest --time 900 --queue-pattern 'perf-test-%d' --queue-pattern-from 1 --queue-pattern 'perf-test-%d' --queue-pattern-from 1 --queue-pattern-to 2 --producers 2 --consumers 8 --queue-args x-cancel-on-ha-failover=true --flag persistent --uri amqp://admin:secretpassword@rmq-ha-rabbitmq-ha:5672?failover=failover_exchange &```
- View RabbitMQ-Overview dashboard (via Web Preview on port 8080)
	- ```kubectl port-forward -n monitoring $(kubectl get po -n monitoring -l app.kubernetes.io/instance=my-grafana -o name) 8080:3000```
	- "Foursquare icon"-->"Dashboards" (mid left side vertical)
		- Click "Manage"
			- Click "RabbitMQ-Overview" (list item (boxed))
###
#### 9) Teardown
- ```terraform destroy``` (from within ```terraform-google-gke/``` cloned repo directory)
###
#### Additional Scenarios:
- Import/Export RabbitMQ Cluster Definitions

-------------------------

# __Next Steps__

## Highlevel Guides

-------------------------

### Deploying RabbitMQ to Kubernetes: What's Involved?
- https://www.rabbitmq.com/blog/2020/08/10/deploying-rabbitmq-to-kubernetes-whats-involved/
	- Use a Persistent Volume for Node Data
	- Node Authentication Secret: the Erlang Cookie
	- Administrator Credentials
	- Node Configuration
	- Readiness Probe
	- Liveness Probe
	- Plugins
	- Ports
	- Create a Service for Client Connections
	- Run The Pod As the rabbitmq User
		- Pod Security Context, Security Context
	- Importing Definitions
		- https://www.rabbitmq.com/definitions.html
			- #import-on-boot
			- #import-after-boot
	- Resource Usage and Limits
	- Using rabbitmq-perf-test to Run a Functional and Load Test of the Cluster
	- Monitoring the Cluster
	- Alternative Option: the Kubernetes Cluster Operator for RabbitMQ


### Production Checklist
- https://www.rabbitmq.com/production-checklist.html

### Clustering Guide
- https://www.rabbitmq.com/clustering.html

### Reliability Guide
- https://www.rabbitmq.com/reliability.html

### Backup and Restore
- https://www.rabbitmq.com/backup.html

### Monitoring
- https://www.rabbitmq.com/monitoring.html

### Memory and Disk Alarms
- https://www.rabbitmq.com/alarms.html

### Reasoning about Memory Use
- https://www.rabbitmq.com/memory-use.html

### Authentication, Authorization, Access Control
- https://www.rabbitmq.com/access-control.html

### Networking and RabbitMQ
- https://www.rabbitmq.com/networking.html

### TLS Support
- https://www.rabbitmq.com/ssl.html

### Runtime Tuning
- https://www.rabbitmq.com/runtime.html

### Queues (and runtime characteristics of)
- https://www.rabbitmq.com/queues.html
- https://www.rabbitmq.com/queues.html#runtime-characteristics
	- - **Lazy Queues** https://www.rabbitmq.com/lazy-queues.html
### Persistence Configuration
- https://www.rabbitmq.com/persistence-conf.html

### Parameters and Policies 
- https://www.rabbitmq.com/parameters.html

			While much of the configuration for RabbitMQ lives in the configuration file, some things do not mesh well with the use of a configuration file:

            If they need to be the same across all nodes in a cluster
            If they are likely to change at run time

            RabbitMQ calls these items parameters. Parameters can be set by invoking rabbitmqctl or through the management plugin's HTTP API. There are 2 kinds of parameters: vhost-scoped parameters and global parameters. Vhost-scoped parameters are tied to a virtual host and consist of a component name, a name and a value. Global parameters are not tied to a particular virtual host and they consist of a name and value.

			One special case of parameters usage is policies, which are used for specifying optional arguments for groups of queues and exchanges, as well as plugins such as Federation and Shovel. Policies are vhost-scoped.


-------------------------

## Semi-Prioritized Next Steps

-------------------------

### ~~0) Resolve error with alert rules. (templating error conflict(s) between go/helm (alerting rules use go templating and when included (directly) in helm templated ConfigMap, errors...)~~

### ~~1) Explore Using ```prometheus-operator```~~
~~- helm chart contains prometheus, alertmanager and grafana **(and perhaps will solve the issue of alert rules (labels not recognized) and more centralized config)**~~
~~- map over config from ```000_cross_env_vars.yaml``` (prometheus-operator vars)~~
	- NOTE: from ```eks-with-day-two-operations```
	
### 2) From https://docs.portworx.com/portworx-install-with-kubernetes/application-install-with-kubernetes/rabbitmq
- "Create a RabbitMQ policy for HA"
- "Create a containerized testing environment"

### 3) From https://sysdig.com/blog/kubernetes-monitoring-with-prometheus-alertmanager-grafana-pushgateway-part-2
- "Prometheus metrics for ephemeral jobs - Push Gateway"
- "Prometheus persistent metrics storage" (data directory and retention period)
	- "On average, Prometheus uses only around 1-2 bytes per sample. Thus to plan the capacity of a Prometheus server, you can use the rough formula:
		- ```needed_disk_space = retention_time_seconds * ingested_samples_per_second * bytes_per_sample```
		- https://prometheus.io/docs/prometheus/latest/storage/
	- "Prometheus server(s) can also regularly forward the metrics to a remote endpoint and only store the last uncommited chunk of readings locally. Some cloud-scale / multisite Prometheus solutions like Cortex or Thanos solutions make use of this feature, we will cover them on the last chapter of this guide."

### 4) Benchmarks, Cluster sizing (capacity planning) and relevant use cases
- NOTE: **Blog posts tagged 'Capacity Planning'** https://www.rabbitmq.com/blog/tag/capacity-planning/
- NOTE: **Archive for 'Performance' Category** https://www.rabbitmq.com/blog/category/performance-2/
- https://www.rabbitmq.com/blog/2020/06/04/how-to-run-benchmarks/
- https://www.rabbitmq.com/blog/2020/06/18/cluster-sizing-and-other-considerations/
	- Mirrored Queues
		- https://www.rabbitmq.com/blog/2020/06/18/cluster-sizing-case-study-mirrored-queues-part-1/
		- https://www.rabbitmq.com/blog/2020/06/18/cluster-sizing-case-study-mirrored-queues-part-2/
	- Quorum Queues
			- https://www.rabbitmq.com/blog/2020/06/23/quorum-queues-local-delivery/
		- https://www.rabbitmq.com/blog/2020/06/18/cluster-sizing-case-study-quorum-queues-part-1/
		- https://www.rabbitmq.com/blog/2020/06/18/cluster-sizing-case-study-quorum-queues-part-2/

### 5) More with PerfTest
- https://rabbitmq.github.io/rabbitmq-perf-test/stable/htmlsingle/

		
-------------------------