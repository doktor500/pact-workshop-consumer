### Consumer Step 6 (Modify existing contract and deploy, contract is compatible)

We are going to develop features that involve changes and verifications to existing and new contracts since for every feature branch we need to set up a new hook in the broker, let's start by creating a script that automates this process.

In the `pact-workshop-consumer` directory run `mkdir scripts`, `touch scripts/create-hook.sh` and `chmod +x scripts/create-hook.sh` to create the script that will configure new hooks in the broker.

The content of the `create-hook.sh` file should look like:

```bash
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
```

With the script is in place, run it with './scripts/create-hook.sh'. You should receive a successful JSON response back from the broker. You might be interested to automate the creation of the hook on a CI/CD step, this request is idempotent so it can be run multiple times, however, we won't be doing it as part of this workshop.

Now let's take a look at the development flow when we make a change to an existing contract. In this case, we are going to make a non-breaking change with regard to the version of the provider that is deployed to production.

Go to the `spec/payment_service_client.rb` test and change the `valid_payment_method` value from `1234123412341234` to `1111222233334444`. Run rspec and see what happens, the tests should finish successfully and you should see that the contract that can be found in the `spec/pacts` directory has changed.

Create a new commit that includes all the changes, push them to GitHub and see what happens. Circleci should trigger a build for your branch and it will execute the following operations:

- The build runs the unit tests.
- The build publishes the changed contract to the broker.
- The build executes the `can-i-deploy` check and it fails, since in the broker, this contract is unverified, the build should be red and you should see a github red icon highlighting it.
- When the broker published the changed contract to the broker in the previous step, the global hook in the broker was triggered, and the `verify` build step in the provider run as a consequence of it.
- The verify step (executed in the provider's master branch) successfully verifies the contract since it already has the code that supports this feature and publishes the verification results back to the broker.
- In the broker, we should see the contract as verified.
- At this stage, the hook that you created this time with the `create-hook.sh` script is triggered and the `test` build in the consumer is run again.
- The `test` build step is executed and finally the `can-i-deploy` check succeeds.
- On github, you should see that circleci changes the icon from red to green. You are ready to merge this feature branch to master in order to deploy it to production.

Merge the PR to master, the `test` and `deploy` build steps will run and after the deployment happens, the version of the consumer that you have just deployed will be tagged in the broker with the `production` tag. Take a look at the broker and see that indeed this is the case.

In the `pact-workshop-consumer` directory, run `git clean -df && git checkout . && git checkout consumer-step7` and follow the instructions in the **Consumers's** readme file
