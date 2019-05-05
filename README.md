### Consumer Step 7 (Contract with breaking changes, wait until the provider supports it)

In this step, the consumer wants to introduce a new feature that it is not yet supported by the provider. The consumer has the need for validating credit card numbers that have length 15 as well as a length equal to 16 digits. The current provider deployed to production only supports credit card numbers of length 16 at the moment.

Since we are going to develop a new feature in the provider, let's start by running the script to create a new hook in the broker for the current branch. Execute './scripts/create-hook.sh' and check that you get a successful JSON response back.

In the `payment_service_client_spec.rb` file add the following test:

```ruby
context "given a new valid type of payment method with 15 digits" do
  let(:valid_payment_method) { "111122223333444" }
  let(:response_body) do { status: :valid } end
  before do
    payment_service
      .upon_receiving("a request for validating a new valid type of payment method")
      .with(method: :get, path: "/validate-payment-method/#{valid_payment_method}")
      .will_respond_with(
        status: 200,
        headers: {"Content-Type" => "application/json"},
        body: response_body
      )
  end

  it "the call to payment service returns a payment status response with status equal to valid" do
    expect(subject.validate(valid_payment_method)).to eql({ "status" => "valid" })
  end
end
```

Run `rspec` to generate the changes to the existing contract, you should see that the contract that can be found in the `spec/pacts` directory has changed.

Create a new commit that includes all the changes, push them to GitHub, open a pull request for `consumer-step7` branch and see what happens. Circleci should trigger a build for your branch and it will execute the following operations:

- The build runs the unit tests.
- The build publishes the changed contract to the broker.
- The build executes the `can-i-deploy` operation and it fails, since in the broker, this contract is unverified, the build should be red and you should see a github red icon highlighting it.
- When the broker published the changed contract to the broker in the previous step, the global hook in the broker was triggered, and the `verify` build step in the provider run as a consequence of it.
- The verify step (executed in the provider's master branch) verifies the contract but this time the verification result is not successful since the current version of the provider in production (master branch) does not support this feature. The verification results are published back to the broker and the contract should be marked as "verification failed".
- In the broker, we should see the contract in red color and with a "verification failed" status.
- On github, you should still see your branch with a red icon that highlights that your feature branch can't be merged into master.

We have to wait until the provider implements this feature and deploys it to production.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step6` and follow the instructions in the **Provider's** readme file and come back here once you are done with the provider changes

If you followed the previous steps in the **Provider's**, you should have now a provider released to production with the changes that enable this feature, check the PR on github, a new build should have run and the feature branch should be green highlighting that this branch in the consumer can be merged to master.

Merge the PR to master, after the deployment happens, this version of the consumer's contract should be tagged with the `production` tag in the broker.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step7` and follow the instructions in the **Provider's** readme file
