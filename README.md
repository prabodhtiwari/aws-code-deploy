# Github Actions: AWS CodeDeploy 

Perform EC2 deployments from Github using AWS CodeDeploy.


## YAML Definition

Add the following script section of your workflow file:    

```yaml
  uses: prabodhtiwari/aws-code-deploy@v1
  with:
    AWS_ACCESS_KEY_ID: '<string>' # Optional if already defined in the context.
    AWS_SECRET_ACCESS_KEY: '<string>' # Optional if already defined in the context.
    AWS_DEFAULT_REGION: '<string>' # Optional if already defined in the context.
    APPLICATION_NAME: '<string>'
    COMMAND: '<string>' # 'upload' or 'deploy'.

    # Common variables
    # S3_BUCKET: '<string>' # Optional.
    # VERSION_LABEL: '<string>' # Optional.
    # BUNDLE_TYPE: '<string>' # Optional.
    # DEBUG: '<boolean>' # Optional.
    # FOLDER: '<string>' # Optional.

    # Upload variables
    # ZIP_FILE: '<string>'

    # Deploy variables
    # DEPLOYMENT_GROUP: '<string>'
    # FILE_EXISTS_BEHAVIOR: '<string>' # Optional.
    # IGNORE_APPLICATION_STOP_FAILURES: '<boolean>' # Optional.
    # WAIT: '<boolean>' # Optional.
    # EXTRA_ARGS: '<string>' # Optional.
```


## Variables

### Common Variables

| Variable                    | Usage |
| --------------------------- | ----- |
| AWS_ACCESS_KEY_ID (*)       | AWS access key id. |
| AWS_SECRET_ACCESS_KEY (*)   | AWS secret key. |
| AWS_DEFAULT_REGION (*)      | The AWS region code (`us-east-1`, `us-west-2`, etc.) of the region containing the AWS resource(s). For more information, see [Regions and Endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html) in the _Amazon Web Services General Reference_. |
| APPLICATION_NAME (*)        | Application name. |
| COMMAND (*)                 | Mode of operation: `upload` or `deploy`. See the **Details** section to understand how each mode works. |
| BUNDLE_TYPE                 | The [file type](https://docs.aws.amazon.com/codedeploy/latest/APIReference/API_S3Location.html) of the application revision stored in S3: `zip`, `tar`, `tgz`, `YAML` or `JSON`.  Default: `zip`. BUNDLE_TYPE should correspond to ZIP_FILE extension. |
| DEBUG                       | Turn on extra debug information. Default: `false`. |
| FOLDER                      | If the deployable artifact is in any folder inside bucket, specify the folder name|

_(*) = required variable. This variable needs to be specified always when using the action._

### Upload Command Variables
If `COMMAND` is set to `upload`: 

| Variable                    | Usage |
| --------------------------- | ----- |
| ZIP_FILE (*)                | The application artifact to upload to S3. Required for 'update'. Supported [file types](https://docs.aws.amazon.com/codedeploy/latest/APIReference/API_S3Location.html): `zip`, `tar`, `tgz`, `YAML` or `JSON`. File extension should correspond to BUNDLE_TYPE. |
| S3_BUCKET                   | Override the S3 bucket that the application zip is uploaded to and deployed from. The default follows the convention `<application_name>-codedeploy-deployment` |
| VERSION_LABEL               | Override the name of the application revision in S3. The default follows the convention `<application_name>-<build_number>-<commit>` |
_(*) = required variable. This variable needs to be specified always when using the action._


### Deploy Command Variables
If `COMMAND` is set to `deploy`: 

| Variable                    | Usage |
| --------------------------- | ----- |
| DEPLOYMENT_GROUP (*)        | Name of the Deployment Group. |
| S3_BUCKET                   | Override the S3 bucket that the application zip is uploaded to and deployed from. The default follows the convention `<application_name>-codedeploy-deployment` |
| VERSION_LABEL               | Override the name of the application revision in S3. The default follows the convention `<application_name>-<build_number>-<commit>` |
| WAIT                        | Wait for the deployment to complete. Default: `true`. |
| FILE_EXISTS_BEHAVIOR        | Action to take if files already exist in the deployment target location (defined in the AppSpec file). Allowed values: `OVERWRITE`, `DISALLOW`, `RETAIN`, default: `DISALLOW`. |
| IGNORE_APPLICATION_STOP_FAILURES | Ignore any errors thrown when trying to stop the previous version of the deployed application. Default: `false`. |
| EXTRA_ARGS                  | Additional args to pass to `aws deploy create-deployment`. |
_(*) = required variable. This variable needs to be specified always when using the action._



## Details

The action provides 2 modes of operation:

**Upload**

Upload the application (as a zip file) to an S3 bucket, and register a new application revision with CodeDeploy.

By default, the zip file is uploaded to an S3 bucket following the naming convention ```<application_name>-codedeploy-deployment```, which can be overridden
with the `S3_BUCKET` parameter.

The uploaded zip artifact will be named `<application_name>-<build_number>-<commit>`, which can be overridden with the `VERSION_LABEL` parameter.
 

**Deploy**

Deploy a previously uploaded application revision to a deployment group.

By default, the revision S3 bucket containing the revision follows the naming convention ```<application_name>-codedeploy-deployment```, which can be overridden
with the `S3_BUCKET` parameter.

The action will attempt to deploy the application revision matching `<application_name>-<build_number>-<commit>`, which can be overridden with the `VERSION_LABEL` parameter,
and wait until deployment has succeeded.

**Caveats**

*  When you use the `deploy` mode with the default `VERSION_LABEL`, the action will generate a new version label based on the build number and commit hash, so you need to make sure to also run the action
with the `upload` mode withing the same workflow so the corresponding version is preset in S3. If you don't run the `upload` part of the action in the same workflow, you should use explicit `VERSION_LABEL`,
for example, use semantic or other versioning scheme that is decoupled from the build number.
 

## Prerequisites
* An IAM user is configured with sufficient permissions to allow the action to perform a deployment to your application and upload artifacts to the S3 bucket.
* You have configured a CodeDeploy Application and Deployment Group. Here is a simple tutorial from AWS: [Deploy Code to a Virtual Machine](https://aws.amazon.com/getting-started/tutorials/deploy-code-vm/)
* An S3 bucket has been set up to which deployment artifacts will be copied.




## Examples

### Upload
Upload the application `build.zip` to custom S3 bucket called `bucket`, with the application uploaded to S3 as `app-1.0.0`.
 
```yaml
jobs:
  upload-app:
    runs-on: ubuntu-latest
    name: upload app on bucket
    steps:
      - name: use upload command
        id: upload
        uses: prabodhtiwari/aws-code-deploy@v1
        with:
          AWS_DEFAULT_REGION: '$AWS_DEFAULT_REGION'
          AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
          AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
          COMMAND: 'upload'
          APPLICATION_NAME: 'application'
          ZIP_FILE: 'build.zip'
          S3_BUCKET: 'bucket'
          VERSION_LABEL: 'app-1.0.0'
```

### Deploy
Start a deployment and wait for it to finish. The application revision `application-<build-number>-<commit>` from the S3 bucket `application-codedeploy-deployment` will be deployed.

```yaml
jobs:
  deploy-app:
    runs-on: ubuntu-latest
    name: deploy app
    steps:
      - name: use deploy command
        id: deploy
        uses: prabodhtiwari/aws-code-deploy@v1
        with:
          AWS_DEFAULT_REGION: '$AWS_DEFAULT_REGION'
          AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
          AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
          COMMAND: 'deploy'
          APPLICATION_NAME: 'application'
          DEPLOYMENT_GROUP: 'deployment-group'
          WAIT: 'true'
```
