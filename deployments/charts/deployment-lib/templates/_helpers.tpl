{{/*
Return the fully qualified name.
*/}}
{{- define "deployment-lib.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "deployment-lib.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the chart name.
*/}}
{{- define "deployment-lib.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "deployment-lib.securityContext.pod" -}}
runAsNonRoot: true
seccompProfile:
  type: "RuntimeDefault"
{{- with .Values.deploymentlib.podSecurityContext }}
{{ toYaml . }}
{{- end -}}
{{- end -}}

{{- define "deployment-lib.securityContext.container" -}}
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- with .Values.deploymentlib.containerSecurityContext }}
{{ toYaml . }}
{{- end -}}
{{- end -}}