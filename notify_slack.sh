#!/usr/bin/env bash

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

function define_apt() {
    local commands="$@"
    local update_run=false

    for cmd in $commands; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "$cmd is already installed."
        else
            if [ "$update_run" = false ]; then
                echo "Running apt-get update..."
                sudo apt-get update
                update_run=true
            fi
            echo "$cmd is not installed. Installing..."
            sudo apt-get install -y "$cmd" || { echo "Error: Failed to install $cmd" >&2; exit 1; }
        fi
    done
}

function check_notify_slack() {
    echo "Checking required variables..."
    define_var_required "GITHUB_JOB_STATUS" "SLACK_WEBHOOK_URL" "GITHUB_WORKFLOW" "GITHUB_REF" "GITHUB_RUN_URL" "GITHUB_REPOSITORY_NAME" "GITHUB_REPOSITORY_URL" "GITHUB_ACTOR"
    define_var_optional "GITHUB_COMMIT_MESSAGE" "GITHUB_COMMIT_TIMESTAMP"
    echo "Checking dependencies..."
    define_apt bash git curl jq
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
