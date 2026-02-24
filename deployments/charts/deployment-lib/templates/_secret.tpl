{{- define "deployment-lib.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "deployment-lib.fullname" . }}-secret
type: Opaque
data:
  atpTestsGitToken: {{ default "" .Values.ATP_TESTS_GIT_TOKEN | b64enc }}
  atpStorageUsername: {{ default "" .Values.ATP_STORAGE_USERNAME | b64enc }}
  atpStoragePassword: {{ default "" .Values.ATP_STORAGE_PASSWORD | b64enc }}
  atpEnvgeneConfiguration: {{ toJson .Values.ATP_ENVGENE_CONFIGURATION | b64enc }}
{{- end -}}