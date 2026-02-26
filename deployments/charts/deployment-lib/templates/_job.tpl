{{- define "deployment-lib.job" -}}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "deployment-lib.fullname" . }}
  labels:
    app: {{ include "deployment-lib.name" . }}
    metrics-type: atp3-service
spec:
  ttlSecondsAfterFinished: {{ .Values.deploymentlib.ATP_RUNNER_JOB_TTL }}
  template:
    metadata:
      labels:
        metrics-type: atp3-service
    spec:
      {{- if .Values.deploymentlib.SECURITY_CONTEXT_ENABLED }}
      securityContext:
        {{- include "deployment-lib.securityContext.pod" . | nindent 8 }}
      {{- end }}
      {{- if .Values.affinity }}
      affinity: {{- toYaml .Values.deploymentlib.affinity | nindent 8 }}
      {{- end }}
      {{- if .Values.tolerations }}
      tolerations: {{- toYaml .Values.deploymentlib.tolerations | nindent 8 }}
      {{- end }}
      containers:
      - name: atp3-playwright-runner
        image: '{{ default .Values.deploymentlib.DOCKER_TAG .Values.deploymentlib.ATP_TESTS_DOCKER_TAG }}'
        {{- if .Values.SECURITY_CONTEXT_ENABLED }}
        securityContext:
          {{- include "deployment-lib.securityContext.container" . | nindent 12 }}
        {{- end }}
        resources:
          requests:
            memory: '{{ .Values.deploymentlib.MEMORY_REQUEST | default "1000Mi" }}'
            cpu: '{{ .Values.deploymentlib.CPU_REQUEST | default "100m" }}'
          limits:
            memory: '{{ .Values.deploymentlib.MEMORY_LIMIT | default "2000Mi" }}'
            cpu: '{{ .Values.deploymentlib.CPU_LIMIT | default "500m" }}'
        env:
          - name: ATP_TESTS_GIT_REPO_URL
            value: "{{ .Values.deploymentlib.ATP_TESTS_GIT_REPO_URL }}"
          - name: ATP_TESTS_GIT_REPO_BRANCH
            value: "{{ .Values.deploymentlib.ATP_TESTS_GIT_REPO_BRANCH }}"
          - name: ENVIRONMENT_NAME
            value: "{{ .Values.deploymentlib.ENVIRONMENT_NAME }}"
          - name: ATP_STORAGE_PROVIDER
            value: "{{ .Values.deploymentlib.ATP_STORAGE_PROVIDER }}"
          - name: ATP_STORAGE_REGION
            value: "{{ .Values.deploymentlib.ATP_STORAGE_REGION }}"
          - name: ATP_STORAGE_SERVER_URL
            value: "{{ .Values.deploymentlib.ATP_STORAGE_SERVER_URL }}"
          - name: ATP_STORAGE_SERVER_UI_URL
            value: "{{ .Values.deploymentlib.ATP_STORAGE_SERVER_UI_URL }}"
          - name: ATP_REPORT_VIEW_UI_URL
            value: "{{ .Values.deploymentlib.ATP_REPORT_VIEW_UI_URL }}"
          - name: ATP_RUNNER_JOB_EXIT_STRATEGY
            value: "{{ .Values.deploymentlib.ATP_RUNNER_JOB_EXIT_STRATEGY }}"
          - name: CURRENT_DATE
            value: "{{ .Values.deploymentlib.CURRENT_DATE }}"
          - name: CURRENT_TIME
            value: "{{ .Values.deploymentlib.CURRENT_TIME }}"
          - name: ATP_STORAGE_BUCKET
            value: "{{ .Values.deploymentlib.ATP_STORAGE_BUCKET }}"
          - name: ENABLE_JIRA_INTEGRATION
            value: "{{ .Values.deploymentlib.ENABLE_JIRA_INTEGRATION }}"
          - name: MONITORING_ENABLED
            value: "{{ .Values.deploymentlib.MONITORING_ENABLED }}"
          - name: PLAYWRIGHT_TRACE_MODE
            value: "{{ .Values.deploymentlib.PLAYWRIGHT_TRACE_MODE }}"
          - name: ATP_ENVGENE_CONFIGURATION
            valueFrom:
              secretKeyRef:
                name: {{ include "deployment-lib.fullname" . }}-secret
                key: atpEnvgeneConfiguration
          - name: TEST_PARAMS
            valueFrom:
              configMapKeyRef:
                name: {{ include "deployment-lib.fullname" . }}-cm
                key: testParams
          - name: ATP_TESTS_GIT_TOKEN
            valueFrom:
              secretKeyRef:
                name: {{ include "deployment-lib.fullname" . }}-secret
                key: atpTestsGitToken
          - name: ATP_STORAGE_USERNAME
            valueFrom:
              secretKeyRef:
                name: {{ include "deployment-lib.fullname" . }}-secret
                key: atpStorageUsername
          - name: ATP_STORAGE_PASSWORD
            valueFrom:
              secretKeyRef:
                name: {{ include "deployment-lib.fullname" . }}-secret
                key: atpStoragePassword
      restartPolicy: Never
  backoffLimit: 0
{{- end -}}