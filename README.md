### Requirements

- Ruby 2.4.4 (It is already installed if you are using Mac OS X)
- [Docker](https://hub.docker.com/editions/community/docker-ce-desktop-mac)

### Setup the environment

Install bundler if you don't have it already installed

`sudo gem install bundler`

### Install dependencies

- Execute `bundle install`

### Run the tests

- Execute `rspec`

### Step 0

Get familiraised with the code

![System diagram](https://github.com/doktor500/pact-workshop-consumer/blob/master/resources/system-diagram.png "System diagram")

You can run this app by excuting `bundle exec rackup config.ru -p 3000` and then navigate to locahost:3000

There are two microservices in this system. A `consumer` (this repository) and a `provider`.

The "provider" is a PaymentService that validates if a credit card number is valid in the context of that system.

The "consumer" only makes requests to PaymentService to verify payment methods.

Checkout the [Provider](https://github.com/doktor500/pact-workshop-provider/) microservice, so the directory structure looks like:

    drwxr-xr-x - pact-workshop-consumer
    drwxr-xr-x - pact-workshop-provider

Run `git checkout consumer-step1` and follow the instructions in this readme file
