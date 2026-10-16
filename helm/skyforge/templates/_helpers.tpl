{{- define "skyforge.name" -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "skyforge.labels" -}}
app.kubernetes.io/part-of: skyforge
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
skyforge.io/environment: {{ .Values.environment }}
{{- end -}}

{{- define "skyforge.app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "skyforge.name" . }}
app.kubernetes.io/component: api
{{- end -}}

{{- define "skyforge.db.selectorLabels" -}}
app.kubernetes.io/name: {{ include "skyforge.name" . }}-postgres
app.kubernetes.io/component: database
{{- end -}}

{{- define "skyforge.db.host" -}}
{{ include "skyforge.name" . }}-postgres
{{- end -}}

{{- define "skyforge.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "skyforge.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}
