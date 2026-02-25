{{- define "deployment-lib.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "deployment-lib.fullname" . }}-cm
data:
  testParams: |
    {{ toJson .Values.TEST_PARAMS | nindent 4 }}
{{- end -}}