#!/usr/bin/env bash

# This script is specifically designed for the GitHub Action sudo88com/slacknotify-action@v1.
# Running it outside of GitHub Actions may result in dependency issues. Use at your own risk.

set -o errexit -o pipefail

function define_var_required() {
    local variables="$@"
    for var in $variables; do
        if [ -n "${!var}" ]; then
            echo "$var=${!var}"
        else
            echo "Error: $var is not set" >&2
            exit 1
        fi
    done
}

function define_var_optional() {
    local variables="$@"
    for var in $variables; do
        if [ -n "${!var}" ]; then
            echo "$var=${!var}"
        else
            echo "Warning: $var is not set" >&2
        fi
    done
}

function check_notify_slack() {
    echo "Checking required variables..."
    define_var_required "GITHUB_JOB_STATUS" "SLACK_WEBHOOK_URL" "GITHUB_WORKFLOW" "GITHUB_REF" "GITHUB_RUN_URL" "GITHUB_REPOSITORY_NAME" "GITHUB_REPOSITORY_URL" "GITHUB_ACTOR"
    define_var_optional "GITHUB_COMMIT_MESSAGE" "GITHUB_COMMIT_TIMESTAMP" # Does not work on workflow_dispatch
}

function send_notify_slack() {
    local webhook_url="${SLACK_WEBHOOK_URL:-N/A}"
    local status="${GITHUB_JOB_STATUS:-N/A}"
    local action_name="${GITHUB_WORKFLOW:-N/A}"
    local emoji
    local prefix
    local message

    if [ "$status" == "success" ]; then
        message="Deployment *succeeded* for project <$GITHUB_REPOSITORY_URL|$GITHUB_REPOSITORY_NAME>"
        emoji=":white_check_mark:"
    else
        message="Deployment *failed* for project <$GITHUB_REPOSITORY_URL|$GITHUB_REPOSITORY_NAME>"
        emoji=":x:"
    fi
    prefix="${emoji} *${action_name}*"
    local json_payload
    json_payload=$(jq -n \
        --arg prefix "$prefix" \
        --arg message "$message" \
        --arg committer "*Committer:* ${GITHUB_ACTOR:-N/A}" \
        --arg commit_msg "*Commit Message:* ${GITHUB_COMMIT_MESSAGE:-N/A}" \
        --arg branch_tag "*Branch/Tag:* ${GITHUB_REF:-N/A}" \
        --arg timestamp "*Commit Timestamp:* ${GITHUB_COMMIT_TIMESTAMP:-N/A}" \
        --arg pipeline_url "*Pipeline URL:* <${GITHUB_RUN_URL:-about:blank}|View Pipeline>" \
        '{ "blocks": [ { "type": "header", "text": { "type": "plain_text", "text": $prefix } }, { "type": "section", "text": { "type": "mrkdwn", "text": $message } }, { "type": "context", "elements": [ { "type": "mrkdwn", "text": $committer }, { "type": "mrkdwn", "text": $commit_msg }, { "type": "mrkdwn", "text": $branch_tag }, { "type": "mrkdwn", "text": $timestamp }, { "type": "mrkdwn", "text": $pipeline_url } ] } ] }')
    curl -s -X POST -H 'Content-type: application/json' --data "$json_payload" "$webhook_url" || { echo "Error: Failed to send Slack notification" >&2; exit 1; }
}

function send() {
    check_notify_slack
    send_notify_slack
}

if [ "$#" -eq 1 ]; then
    "$1"
else
    echo "Usage: $0 <function_name>" >&2
    exit 1
fi
