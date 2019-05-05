### Consumer Step 4 (Setting up CD)

This step is the beginning of the **Part II** of this workshop.

In this step we want to have everything working in the cloud, so we are going to use [pactflow.io](https://pactflow.io/) in order to set up a pact-broker that we can access everywhere.

Once you have successfully created an account on pactflow.io, you should continue with the instructions in this readme file.

The instructions to set up a pact-broker in pactflow.io can be found here

[creating-a-pact-broker-account-on-pactflowio](https://github.com/doktor500/pact-workshop-broker#creating-a-pact-broker-account-on-pactflowio)

Now that you have a pact-broker in the cloud we can continue with the steps to set up a CD pipeline, for that we are going to use [heroku](http://heroku.com) and [circleci](https://circleci.com) for it.

#### Create an account on heroku

Navigate to [heroku](http://heroku.com), click on the "Sign up" button and follow the instructions to create a free account.

![Heroku Step 1
](resources/heroku-step1.png "Heroku Step 1")

![Heroku Step 2](resources/heroku-step2.png "Heroku Step 2")

Check your email, confirm your account and complete the registration process creating a password, save the login credentials to a safe place (browser, one password, etc.) since we will need them later.

![Heroku Step 3](resources/heroku-step3.png "Heroku Step 3")

![Heroku Step 4](resources/heroku-step4.png "Heroku Step 4")

Finally you should be able to see your heroku account dashboard

![Heroku Step 5](resources/heroku-step5.png "Heroku Step 5")

Click on the user icon on the top-right corner and select "Account settings". Scroll down and in the "API Key" section, click on the "Reveal button". Copy the API key to your clipboard and save it in a safe place, we will need it later to setup circleci and enable automatic deployments to heroku.

![Heroku Step 6](resources/heroku-step6.png "Heroku Step 6")

#### Install heroku-cli

Now let's setup heroku-cli. Navigate to [heroku-cli](https://devcenter.heroku.com/articles/heroku-cli) and follow the instructions for your operating system.

Once heroku-cli is installed, navigate to `pact-workshop-consumer` in your terminal and execute `heroku login`, follow the instructions to log in using your browser.

#### Create heroku consumer app

First, check that your `$GITHUB_USER` environment variable is set correctly by running.

```bash
echo $GITHUB_USER
```

You should see your github user name printed on the terminal, if that is not the case, make sure the environment variable is set globally and you can access it in your terminal session.

Create a heroku app by executing `heroku create pact-consumer-$GITHUB_USER`. This is the heroku app name that will be used to create the consumer app URL, so we need a unique identifier to avoid collisions. Be aware that the limit for the app name is 30 characters.

The app URL will look like `https://pact-consumer-$GITHUB_USER.herokuapp.com/`

#### Configure heroku environment variables

The consumer app needs to talk to the provider API that we will deploy shortly. In order to do so, we need to set an environment variable with the URL of the provider API.

In your terminal, copy paste the following command and execute it.

```bash
heroku config:set PAYMENT_SERVICE_ENDPOINT=https://pact-provider-$GITHUB_USER.herokuapp.com/
```

#### Create heroku configuration file

In the `pact-workshop-consumer` directory run `touch Procfile` to create the configuration file for heroku to be able to run the app

The content of the `Procfile` file should look like:

```
web: bundle exec rackup config.ru -p $PORT
```

#### Create an account on circleci

Now, let's create a circleci account. Navigate to [circleci](https://circleci.com), click on the "Sign up" button and follow the instructions to sign up with github.

![Circleci Step 1](resources/circleci-step1.png "Circleci Step 1")

![Circleci Step 2](resources/circleci-step2.png "Circleci Step 2")

In the "Getting started" page, select both projects in the list of projects and click the "Follow" button.

![Circleci Step 3](resources/circleci-step3.png "Circleci Step 3")

You should finally see a page similar to this

![Circleci Step 4](resources/circleci-step4.png "Circleci Step 4")

#### Configure circleci environment variables

Now, let's setup the environment variables need it to deploy the consumer application. Click on the "WORKFLOWS" icon in the left-hand side menu bar, and click on the settings icon for the `pact-workshop-consumer` project.

Click on the "Environment variables" link, you should see a page similar to this:

![Circleci Step 5](resources/circleci-step5.png "Circleci Step 5")

We need to add 5 environment variables:

  - HEROKU_API_KEY
  - HEROKU_APP_NAME
  - PACT_BROKER_BASE_URL
  - PACT_BROKER_TOKEN
  - PACT_PARTICIPANT

Click on the "Add variables" button and add them one by one.

Use the `HEROKU_API_KEY` that you created in the previous step, and set the `HEROKU_APP_NAME` to `pact-consumer-$GITHUB_USER`.

If you followed the steps available in the [pact-workshop-broker](https://github.com/doktor500/pact-workshop-broker) repository, you can get the `PACT_BROKER_BASE_URL` and `PACT_BROKER_TOKEN` by running

```bash
echo $PACT_BROKER_BASE_URL
echo $PACT_BROKER_TOKEN
```

The `PACT_PARTICIPANT` environment variable value should be set to `PaymentServiceClient`

#### Create circleci API token

Now, let's create a circleci Personal API Token, (we will use it later to make calls to circleci API form the broker). Click on the icon on the top right-hand side corner, and choose "User settings".

![Circleci Step 6](resources/circleci-step6.png "Circleci Step 6")

Create a new token and name it with something meaningful like "pact-broker", copy the token to your clipboard, and use it to create the following environment variable, we will need it later to set up the hooks in the pact-broker.

In your `~/.basrc`, `~/.zshrc`, `~/.fishrc` etc, add the following line.

```bash
export CIRCLECI_API_TOKEN=${YOUR_CIRCLECI_API_TOKEN}
```

Replacing the token with the right value.

Restart your terminal or source the file in all your active tabs `source ~/.basrc`, `source ~/.zshrc`, `source ~/.fishrc` etc.

You should be able to execute

```bash
echo $CIRCLECI_API_TOKEN
```

And see the correct value.

![Circleci Step 7](resources/circleci-step7.png "Circleci Step 7")

#### Create configuration files for circleci

Now, let's create a YAML file to configure circleci.

In the `pact-workshop-consumer` directory run `mkdir .circleci` and `touch .circleci/config.yml` to create the circle-ci configuration file.

The content of the `config.yml` file should look like:

```yaml
version: 2

jobs:
  test:
    working_directory: /tmp/project/
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout

      - run:
          name: Install dependencies
          command: bundle install

      - run:
          name: Run tests
          command: |
            mkdir -p /tmp/project/test-results
            TEST_FILES="$(circleci tests glob "spec/**/*_spec.rb" | circleci tests split --split-by=timings)"

            bundle exec rspec \
              --format progress \
              --format RspecJunitFormatter \
              --out /tmp/project/test-results/rspec.xml \
              --format progress \
              $TEST_FILES

      - store_test_results:
          path: /tmp/project/test-results

      - store_artifacts:
          path: /tmp/project/test-results
          destination: test-results

      - run:
          name: Publish contracts
          command: rake pact:publish

      - run:
          name: Check if contracts are verified
          command: |
            bundle exec pact-broker can-i-deploy \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --to production

  deploy:
    working_directory: /tmp/project/
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout

      - run:
          name: Install dependencies
          command: bundle install

      - run:
          name: Check if deployment can happen
          command: |
            bundle exec pact-broker can-i-deploy \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --to production

      - run:
          name: Deploy to production
          command: |
            git push https://heroku:${HEROKU_API_KEY}@git.heroku.com/${HEROKU_APP_NAME}.git master

            bundle exec pact-broker create-version-tag \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --tag production

workflows:
  version: 2
  pipeline:
    jobs:
      - test
      - deploy:
          requires:
            - test
          filters:
            branches:
              only: master
```

Take a look at the circleci config file. You will see that there is a workflow composed of 2 different jobs.

The first job named `test` performs the following actions:

  - Checkouts the code.
  - Installs and caches the project dependencies.
  - Runs the test and stores the test results.
  - Executes the `rake pact:publish` task and publishes the results to the broker.
  - Checks if the branch can be deployed using the `can-i-deploy` command.

The second job named `deploy` depends on the `test` job and it is only executed in master branch, it performs the following actions:

  - Checkouts the code.
  - Installs the project dependencies.
  - Checks if the deployment to production can happen.
  - If the deployment can happen, it deploys and updates the `production` tag in the broker.

Navigate to the directory in where you checked out `pact-workshop-provider`, run `git clean -df && git checkout . && git checkout provider-step4` and follow the instructions in the **Provider's** readme file
