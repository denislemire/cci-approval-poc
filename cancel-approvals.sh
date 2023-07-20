#!/bin/bash

# Retrieve the CircleCI API token from the environment variable
TOKEN=$(op item get vdhoqk4qqmqyxm274lsajqhw2y --fields token)
SLUG="gh/denislemire"
MAX_HOURS=0

function process_page() {
	local page_token=$1

	echo "Retrieving pipelines..."

	# Make the API request
	RESPONSE=$(curl -s \
		--request GET \
		--url "https://circleci.com/api/v2/pipeline?org-slug=${SLUG}${page_token}" \
		--header "Circle-Token: ${TOKEN}"
	)

	pipeline_ids=$(echo "$RESPONSE" | jq -r '.items[].id')

	# Loop through the item IDs and process each one
	while IFS= read -r pipeline_id; do
		get_pipeline "$pipeline_id"
	done <<< "$pipeline_ids"
};

function get_pipeline() {
	local pipeline_id=$1

	echo "Retrieving workflows for ${pipeline_id}"

	RESPONSE=$(curl -s \
		--request GET \
		--url "https://circleci.com/api/v2/pipeline/${pipeline_id}/workflow" \
		--header "Circle-Token: ${TOKEN}"
	)

	on_hold_json=$(echo "$RESPONSE" | jq -r '.items[] | select(.status == "on_hold")')

	echo $on_hold_json | jq .

	on_hold_and_old_ids=$(echo "$on_hold_json" | jq -r --argjson max_hours "$MAX_HOURS" '
		select((.created_at | fromdateiso8601) < (now - ($max_hours * 3600)))
		| .id
	')

	for id in $on_hold_and_old_ids; do
		cancel_workflow "$id"
	done
}

function cancel_workflow() {
	local workflow_id=$1

	echo "Cancelling ${workflow_id}"

	RESPONSE=$(curl -s \
		--request POST \
		--url "https://circleci.com/api/v2/workflow/${workflow_id}/cancel" \
		--header "Circle-Token: ${TOKEN}"
	)

	echo $RESPONSE | jq .
};

# Process the first page
process_page ""

# Process subsequent pages using the next page token
NEXT_PAGE_TOKEN=$(echo "$RESPONSE" | jq -r '.next_page_token')

while [[ "$NEXT_PAGE_TOKEN" != "null" ]]; do
	process_page "&page-token=${NEXT_PAGE_TOKEN}"
	NEXT_PAGE_TOKEN=$(echo "$RESPONSE" | jq -r '.next_page_token')
done
