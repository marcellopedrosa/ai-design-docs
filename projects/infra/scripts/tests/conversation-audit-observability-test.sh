#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
dashboard="$repository_root/infra/monitoring/grafana/dashboards/conversation-audit.json"
alerts="$repository_root/infra/monitoring/prometheus/alert_rules.yml"
application_config="$repository_root/backend/app/src/main/resources/application.yml"
conversation_retention_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/adapter/MicrometerConversationRetentionMetricsAdapter.java"
access_retention_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/infrastructure/scheduler/ConversationAuditAccessRetentionScheduler.java"
policy_retention_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/tenant/internal/application/service/ConversationAuditRetentionPolicyService.java"
webhook_submission_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/service/InboundWebhookSubmissionMetrics.java"
webhook_queue_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/shared/config/async/AsyncConfig.java"
business_metrics_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/shared/config/metrics/BusinessMetricsService.java"
tenant_observation_filter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/shared/config/metrics/TenantObservationFilter.java"
usage_reporter_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/billing/internal/infrastructure/scheduler/UsageReporterScheduler.java"
llm_response_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/service/LlmResponseService.java"
chatbot_flow_emitter="$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/usecase/ChatbotFlowUseCase.java"

jq -e '
  .uid == "conversation-audit-ops"
  and .editable == false
  and (.templating.list | length) == 0
  and (.panels | length) >= 14
  and ([.panels[].targets[].expr] | all(
    contains("conversation_audit_")
    or contains("chatbot_outbound_reconciliation_incident_total")
  ))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_backfill_runs_total")))
  and ([.panels[].targets[].expr] | any(contains("chatbot_outbound_reconciliation_incident_total")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_runs_total")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_rows_total")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_duration_seconds")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_policy_resolution_total")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_readiness")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_lag_seconds")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_policy_version_divergence")))
  and ([.panels[].targets[].expr] | any(contains("conversation_audit_retention_last_success_timestamp_seconds")))
  and ([.panels[].targets[].expr] | any(contains("policy_not_ready")))
  and ([.panels[].targets[].expr] | any(contains("backup_not_ready")))
' "$dashboard" >/dev/null

if grep -Eiq 'tenant[_ -]?id|user[_ -]?id|conversation[_ -]?id|remote[_ -]?(number|identifier)|provider[_ -]?id|correlation[_ -]?id' "$dashboard" "$alerts"; then
    echo "Conversation Audit observability contains a forbidden identity/high-cardinality dimension." >&2
    exit 1
fi

for alert_name in \
    ConversationAuditDecryptFailure \
    ConversationAuditUnavailable \
    ConversationAuditServerErrorRatio \
    ConversationAuditDeniedAnomaly \
    ConversationAuditRateLimitedSustained \
    ConversationAuditSearchP95Degraded \
    ConversationAuditDetailOrRevealP95Degraded \
    ConversationAuditMessagesP95Degraded \
    ConversationAuditBackfillFailure \
    ConversationAuditTerminalTimelineGap \
    ConversationAuditAssociationConflict \
    ConversationAuditWebhookSaturation \
    ConversationAuditRetentionFailure \
    ConversationAuditRetentionLedgerGap \
    ConversationAuditRetentionPolicyNotReady \
    ConversationAuditRetentionBackupNotReady \
    ConversationAuditRetentionTelemetryAbsent \
    ConversationAuditRetentionReadinessNegative \
    ConversationAuditRetentionLagHigh \
    ConversationAuditRetentionPolicyVersionDivergence; do
    grep -Fq "alert: $alert_name" "$alerts" || {
        echo "Missing Conversation Audit alert: $alert_name" >&2
        exit 1
    }
done

[ "$(grep -c 'team: security-sre' "$alerts")" -ge 20 ] || {
    echo "Every Conversation Audit alert must have the security-sre owner." >&2
    exit 1
}

for webhook_metric in \
    conversation_audit_webhook_submissions_total \
    conversation_audit_webhook_queue_depth \
    conversation_audit_webhook_queue_capacity; do
    grep -Fq "$webhook_metric" "$alerts" || {
        echo "Webhook saturation alert is missing metric $webhook_metric." >&2
        exit 1
    }
done
grep -Fq 'outcome="rejected_saturated"' "$alerts" || {
    echo "Webhook saturation alert must select only the rejected_saturated outcome." >&2
    exit 1
}
grep -Fq 'channel=~"whatsapp|telegram"' "$alerts" || {
    echo "Webhook saturation alert must use the finite channel allowlist." >&2
    exit 1
}
grep -Fq 'conversation_audit_retention_ledger_gap_total{dataset="conversation"}' "$alerts" || {
    echo "Retention ledger-gap alert must select only dataset=conversation." >&2
    exit 1
}

grep -Fq '"conversation_audit_webhook_submissions_total"' "$webhook_submission_emitter" || {
    echo "Inbound webhook submission metric is not emitted." >&2
    exit 1
}
for channel in whatsapp telegram; do
    grep -Fq "counter(meterRegistry, \"$channel\", \"rejected_saturated\")" \
        "$webhook_submission_emitter" || {
        echo "Inbound webhook saturation outcome is missing channel=$channel." >&2
        exit 1
    }
done
for queue_metric in \
    conversation_audit_webhook_queue_depth \
    conversation_audit_webhook_queue_capacity; do
    grep -Fq "\"$queue_metric\"" "$webhook_queue_emitter" || {
        echo "Inbound webhook executor does not emit $queue_metric." >&2
        exit 1
    }
done

grep -Fq 'conversation_audit_duration: true' "$application_config" || {
    echo "Conversation Audit timer histogram is not enabled." >&2
    exit 1
}
grep -Fq 'conversation_audit_duration: 0.5,0.95,0.99' "$application_config" || {
    echo "Conversation Audit timer percentiles are incomplete." >&2
    exit 1
}

grep -Fq '"conversation_audit_backfill_runs"' \
    "$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/infrastructure/crypto/ConversationAuditBackfillRunner.java" || {
    echo "Conversation Audit backfill outcome metric is not emitted." >&2
    exit 1
}
grep -Fq '"association_conflict"' \
    "$repository_root/backend/app/src/main/java/br/com/duoset/saas_service/contexts/omnichannel/internal/application/service/MessageAuditService.java" || {
    echo "Conversation Audit association-conflict metric is not emitted." >&2
    exit 1
}

for emitter in "$conversation_retention_emitter" "$access_retention_emitter"; do
    for metric in \
        conversation_audit_retention_runs_total \
        conversation_audit_retention_rows_total \
        conversation_audit_retention_duration_seconds; do
        grep -Fq "\"$metric\"" "$emitter" || {
            echo "Retention emitter does not publish the canonical metric $metric: $emitter" >&2
            exit 1
        }
    done
    for state_metric in \
        conversation_audit_retention_readiness \
        conversation_audit_retention_lag_seconds \
        conversation_audit_retention_last_success_timestamp_seconds \
        conversation_audit_retention_purge_active \
        conversation_audit_retention_schedule_interval_seconds; do
        grep -Fq "\"$state_metric\"" "$emitter" || {
            echo "Retention emitter does not publish state metric $state_metric: $emitter" >&2
            exit 1
        }
    done
    grep -Fq 'AtomicInteger readiness = new AtomicInteger();' "$emitter" || {
        echo "Retention readiness must start fail-closed at zero: $emitter" >&2
        exit 1
    }
done

grep -Fq '"conversation_audit_retention_policy_resolution_total"' \
    "$policy_retention_emitter" || {
    echo "Retention policy resolution metric is not emitted." >&2
    exit 1
}

grep -Fq '"conversation_audit_retention_policy_version_divergence"' \
    "$policy_retention_emitter" || {
    echo "Retention policy version divergence metric is not emitted." >&2
    exit 1
}
for dataset in conversation audit_access; do
    grep -Fq "Tags.of(\"dataset\", \"$dataset\")" \
        "$policy_retention_emitter" || {
        echo "Policy divergence gauge is missing dataset=$dataset." >&2
        exit 1
    }
done

grep -Fq '"conversation_audit_retention_ledger_gap_total"' \
    "$conversation_retention_emitter" || {
    echo "Conversation retention ledger-gap metric is not emitted." >&2
    exit 1
}

for alert_metric in \
    conversation_audit_retention_purge_active \
    conversation_audit_retention_schedule_interval_seconds \
    conversation_audit_retention_readiness \
    conversation_audit_retention_lag_seconds \
    conversation_audit_retention_policy_version_divergence \
    conversation_audit_retention_last_success_timestamp_seconds; do
    grep -Fq "$alert_metric" "$alerts" || {
        echo "Retention alerts do not enforce state metric $alert_metric." >&2
        exit 1
    }
done

if grep -Eiq '"(tenant_id|tenantId|user_id|userId|conversation_id|conversationId|provider_id|providerId)"' \
    "$conversation_retention_emitter" "$access_retention_emitter" "$policy_retention_emitter"; then
    echo "Retention metrics contain a forbidden identity/high-cardinality label." >&2
    exit 1
fi

grep -Fq 'addHighCardinalityKeyValue(KeyValue.of(TENANT_TAG, tenantId))' \
    "$tenant_observation_filter" || {
    echo "Tenant observation correlation must be high-cardinality trace data." >&2
    exit 1
}
if grep -Fq 'addLowCardinalityKeyValue(KeyValue.of(TENANT_TAG' "$tenant_observation_filter"; then
    echo "Tenant observation correlation must never be low-cardinality." >&2
    exit 1
fi
grep -Fq 'addLowCardinalityKeyValue(KeyValue.of(MODULE_TAG, module))' \
    "$tenant_observation_filter" || {
    echo "The finite module dimension must remain low-cardinality." >&2
    exit 1
}
grep -Fq 'ALLOWED_MODULES.contains(module)' "$tenant_observation_filter" || {
    echo "The module metric dimension must be allowlisted." >&2
    exit 1
}

if grep -Eq '\.tag\("(tenant|tenant_id|tenantId|model|user_id|userId|conversation_id|message_id)"' \
    "$business_metrics_emitter"; then
    echo "Business metrics contain an identity/model label." >&2
    exit 1
fi
if grep -Eq 'record[A-Za-z]+\(String tenantId|register[A-Za-z]+\(String tenantId' \
    "$business_metrics_emitter"; then
    echo "Business metric APIs must not accept tenant identity." >&2
    exit 1
fi
for dimension in \
    FISCAL_QUERY_TYPES FISCAL_RESULTS DIRECTIONS CHATBOT_CHANNEL_TYPES CHATBOT_BLOCK_REASONS \
    PLANS PAYMENT_METHODS LLM_PROVIDERS; do
    grep -Fq "$dimension" "$business_metrics_emitter" || {
        echo "Business metric allowlist is missing: $dimension" >&2
        exit 1
    }
done
grep -Fq 'requireAllowed("channel_type", channelType, CHATBOT_CHANNEL_TYPES)' \
    "$business_metrics_emitter" || {
    echo "Chatbot usage channel_type is not validated before registration." >&2
    exit 1
}
grep -Fq 'synchronized (registry)' "$business_metrics_emitter" || {
    echo "Aggregate gauge registration is not serialized per registry." >&2
    exit 1
}

if grep -Fq '"tenant", first.getTenantId()' "$usage_reporter_emitter"; then
    echo "Billing usage metrics still expose tenant UUID." >&2
    exit 1
fi
[ "$(grep -c '"metric_type", first.getMetricType().name()' "$usage_reporter_emitter")" -eq 2 ] || {
    echo "Billing usage metrics must use the finite MetricType enum for both outcomes." >&2
    exit 1
}
grep -Fq 'meterRegistry.counter("llm.fallback.count").increment();' "$llm_response_emitter" || {
    echo "LLM fallback metric must be aggregate and function-free." >&2
    exit 1
}
if grep -F 'llm.fallback.count' "$llm_response_emitter" | grep -Fq '"function"'; then
    echo "LLM fallback metric exposes function identity." >&2
    exit 1
fi
[ "$(grep -c 'recordChatbotUsageBlocked(channel.name()' "$chatbot_flow_emitter")" -eq 3 ] || {
    echo "Chatbot blocked usage metrics must pass the finite channel enum." >&2
    exit 1
}
grep -Fq 'recordChatbotUsageAllowed(channel.name())' "$chatbot_flow_emitter" || {
    echo "Chatbot allowed usage metric must pass the finite channel enum." >&2
    exit 1
}

echo "Conversation Audit observability contract validation passed."
