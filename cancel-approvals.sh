#!/bin/bash

MAX_HOURS=24

if [ -z "$1" ] && [ -z "$SLUG" ]; then
        echo "Usage: $0 vcs_type/org_name [hours] (defaults to 24)"
        exit 1
fi

SLUG=$1

if [ -z "$CIRCLE_TOKEN" ]; then
        echo "We need a token, please set CIRCLE_TOKEN env variable."
        exit 1
fi

if [[ "$2" =~ ^[0-9]+$ ]]; then
        MAX_HOURS=$2
fi

function process_page() {
	local page_token=$1

	echo "Retrieving pipelines..."

	# Make the API request
	RESPONSE=$(curl -s \
		--request GET \
		--url "https://circleci.com/api/v2/pipeline?org-slug=${SLUG}${page_token}" \
		--header "Circle-Token: ${CIRCLE_TOKEN}"
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
		--header "Circle-Token: ${CIRCLE_TOKEN}"
	)

	on_hold_json=$(echo "$RESPONSE" | jq -r --argjson max_hours "$MAX_HOURS" '
		.items[]
		| select(.status == "on_hold")
		| select(
			($max_hours == 0)
			or
			((.created_at | fromdateiso8601) < (now - ($max_hours * 3600)))
		)
	')

	echo "$on_hold_json" | jq .

	on_hold_and_old_ids=$(echo "$on_hold_json" | jq -r '.id')

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
		--header "Circle-Token: ${CIRCLE_TOKEN}"
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
