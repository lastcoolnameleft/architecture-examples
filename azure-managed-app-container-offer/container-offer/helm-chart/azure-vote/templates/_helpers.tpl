{{/*
Expand the name of the chart.
*/}}
{{- define "azure-vote.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "azure-vote.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "azure-vote.labels" -}}
helm.sh/chart: {{ include "azure-vote.name" . }}
{{ include "azure-vote.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "azure-vote.selectorLabels" -}}
app.kubernetes.io/name: {{ include "azure-vote.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Redis selector labels (for in-cluster Redis)
*/}}
{{- define "azure-vote.redisSelectorLabels" -}}
app.kubernetes.io/name: {{ include "azure-vote.name" . }}-redis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
