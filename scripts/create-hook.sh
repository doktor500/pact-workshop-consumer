#!/usr/bin/env bash

GIT_BRANCH=`git rev-parse --abbrev-ref HEAD`

curl \
	--header "Content-Type: application/json" \
	--header "Authorization: Bearer $PACT_BROKER_TOKEN" \
	--request POST "$PACT_BROKER_BASE_URL/webhooks/provider/PaymentService/consumer/PaymentServiceClient" \
	--data '{
	  "events": [{"name": "provider_verification_published"}],
	  "request": {
	    "method": "POST",
	    "headers": { "Content-Type": "application/json" },
	    "username": "'$CIRCLECI_API_TOKEN'",
	    "url": "https://circleci.com/api/v1.1/project/github/'$GITHUB_USER'/pact-workshop-consumer/tree/'$GIT_BRANCH'",
	    "body": {
	      "build_parameters": {"CIRCLE_JOB": "test"}
	    }
	  }
	}'
