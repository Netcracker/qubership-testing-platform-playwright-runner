{{- define "deployment-lib.all" -}}
{{ include "deployment-lib.configmap" . }}
---
{{ include "deployment-lib.secret" . }}
---
{{ include "deployment-lib.job" . }}
{{- end -}}