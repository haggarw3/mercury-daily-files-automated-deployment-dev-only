import * as cdk from '@aws-cdk/core';
import * as glue from '@aws-cdk/aws-glue';
import * as s3 from '@aws-cdk/aws-s3';
import * as lambda from '@aws-cdk/aws-lambda';
import * as lambdaEventSources from '@aws-cdk/aws-lambda-event-sources';
import * as iam from '@aws-cdk/aws-iam';
import * as path from "path";
import * as s3deploy from '@aws-cdk/aws-s3-deployment';
import {env} from '../config/environment'  ;
import { Asset } from "@aws-cdk/aws-s3-assets";
import * as secretsmanager from '@aws-cdk/aws-secretsmanager';
// parameter store is not supported by AWS-CDK


export interface MercuryAwsCdkStackProps extends cdk.StackProps {
	//insert properties you wish to export
  }
export class MercuryAwsCdkStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: MercuryAwsCdkStackProps) {
    super(scope, id, props);

// This is how we can read secrets stored directly using the arn of the secret from the secrets manager 
	const redshift_host = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:dev/mercury-aws-cdk-daily-files/redshift-host-fPQpqp'
	const redshift_dbname = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:dev/mercury-aws-cdk/secrets-WyM0Du'
	const redshift_username = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:RedshiftUsername-usrnam-n0jkLY'
	const redshift_password = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:RedshiftPassword-paswrd-8Mz0L5'
	const redshift_port = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:RedshiftPort-portnu-sM9fAW'
	const account_number = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:AWSaccountnumber-accnum-09QlNG'
	const iam_service_role = 'arn:aws:secretsmanager:us-east-1:464340339497:secret:dev/mercury-daily-files/iam_service_role-a1mwF6'
	
	// to store multiple key-value pairs within the same secret 
	// for eg all the redshift credentials are stored in one secret that has different key value pairs 
	// eg {"redshift_host": "afaaga", "redshift_dbname": "dev" ............}
	// create a secret from its ARN - ie retrieves an existing AWS Secrets Manager secret by its ARN and creates a Secret construct 
	const api_role_ = secretsmanager.Secret.fromSecretCompleteArn(this, 'api_role', 'arn:aws:secretsmanager:us-east-1:464340339497:secret:dev/mercury-aws-cdk-daily-files/cluster_identifier_and_api_role-TSQK9t');
	// retrieve the key-value pairs from the secret's value
	const api_role = api_role_.secretValueFromJson('redshift_api_role')

	// another example
	const redshift_credentials = secretsmanager.Secret.fromSecretCompleteArn(this, 'redshift_credentials', 'arn:aws:secretsmanager:us-east-1:464340339497:secret:dev/mercury-daily-files/redshift-credentials-test-ngkvny');
	// retrieve the key-value pairs from the secret's value
	const dbname = redshift_credentials.secretValueFromJson('redshift_dbName');
	const username = redshift_credentials.secretValueFromJson('redshift_username');
	const password = redshift_credentials.secretValueFromJson('redshift_password');
	// this reduces the number of secrets in Secrets Manager 

	const env_config = {
	 	environment: env.environment,  // Environment - Development/Testing/Staging/Production - AWS dev
		appName: env.appName,
		githubRepoName: env.githubRepoName,
		branchName: env.branchName,
		awsEnv: {
		account_name: env.awsEnv.account_name,
		account_id: account_number, // updated
		region: env.awsEnv.region,
		},
		redshift: {
		host: redshift_host, // updated
		port: redshift_port, // updated
		user: redshift_username,  // updated
		password: redshift_password,  // updated
		dbName: redshift_dbname, // updated
		cluster_identifier: env.redshift.cluster_identifier,
		apiRole: api_role,
		},
		pipeline: {
		jira_project: env.pipeline.jira_project,
		jira_prefix: env.pipeline.jira_prefix,
		},	
		vpc_connection: env.vpc_connection,
		envRole: iam_service_role
	  }

	
	// creating assets for scripts so that they are uploaded in S3 bucket automatically
	//python scripts run in Glue job
    const py_glue_job = new Asset(this, "py-asset-glue", {
		path: path.join(__dirname, "assets/glue-job-run-sql-sp.py"),
	  });

	  // create stage bucket 
	const stage_bucket = new s3.Bucket(this, `${env_config.appName}-stage`,
	  {
		bucketName: `${env_config.appName}-stage`,
		removalPolicy: cdk.RemovalPolicy.DESTROY
	  });

	  // add the contents of assets folder to the stage bucket
	 new s3deploy.BucketDeployment(this, 'loadassets', {
		sources: [s3deploy.Source.asset('./lib/assets')],
		destinationBucket: stage_bucket,
		destinationKeyPrefix: 'scripts', // optional prefix in destination bucket
	  });

	// create destination bucket 
	  new s3.Bucket(this, `${env_config.appName}-csv-destination`,
    {
      bucketName: `${env_config.appName}-csv-destination`,
		removalPolicy: cdk.RemovalPolicy.DESTROY
    });


	// create glue job that will run the SP in Redshift and load the file in an S3 bucket
	const glue_job_run_sql_stored_procedure = new glue.CfnJob(this, `${env_config.appName}-run-sp`, {
		name: `${env_config.appName}-run-sp`,
		description: 'glue job to run SQL stored procedure',
		command: {
		  name: 'pythonshell',
		  pythonVersion: '3',
		//   scriptLocation: 's3://cdk-mercury-daily-files-temp/scripts/cdk_lambda_rename_move_files.py'
		scriptLocation: py_glue_job.s3ObjectUrl
		},
		
		role: `${env_config.envRole}`,
		defaultArguments: {
		  '--TempDir': `s3://aws-glue-temporary-${env_config.awsEnv.account_id}-${env_config.awsEnv.region}/`,
		  '--additional-python-modules': 'aws-psycopg2',
		  '--dbname': env_config.redshift.dbName,
		  '--host': env_config.redshift.host,
		  '--password': env_config.redshift.password, 
		  '--port': env_config.redshift.port, 
		  '--user': env_config.redshift.user,
		  '--s3_load_sql_bucket': `${env_config.appName}-stage`, 
		  '--s3_load_sql_key': 'scripts/cdk_sp_mercury_jan_2023.sql',
		  '--enable-metrics': 'true',
		  '--enable-continuous-cloudwatch-log': 'true',
		  '--job-language': 'python',
		  '--enable-glue-datacatalog': 'false'
		},
		connections: {
		  connections: [env_config.vpc_connection],
		},
		// glueVersion: "3.0", error resolved - not valid for this job
		maxRetries: 0,
		maxCapacity: 1,
		timeout: 300
	  });

	// create the trigger for the glue job. 
	
	  const glue_trigger_Job_run_sp = new glue.CfnTrigger(
		this,
		"glue-trigger-assetJob",
		{
		  name: "Run-Job-" + glue_job_run_sql_stored_procedure.name,
		  type: "SCHEDULED", 
		  schedule: "cron(0 5 * * ? *)",
		  startOnCreation: true, // activates the cron schedule on creation 
		  actions: [
			{
			  jobName: glue_job_run_sql_stored_procedure.name,
			  timeout: 120,
			},
		  ],

		}
	  );
	  //add trigger dependency on the job
	  glue_trigger_Job_run_sp.node.addDependency(glue_job_run_sql_stored_procedure);


	// lambda to rename and move files to the destination folder 
	const lambda_rename_move_files = new lambda.Function(this, `${env_config.appName}-rename-move-files`, {
		runtime: lambda.Runtime.PYTHON_3_7, //execution enviroment
		code: lambda.Code.fromAsset("lib/assets"),  //directory used from where code is loaded
		handler: 'cdk-lambda-rename-move-files.lambda_handler', //name of file.function is lambda_handler in the code for lambda
		timeout: cdk.Duration.minutes(10),
		  });
  
  
	  // create a policy statement
	  // for giving permissions to the lambda to run the glue job
	const lambda_permissions_to_s3 = new iam.PolicyStatement({
		actions: ['s3:*'],
		resources: ['*'],
	  });
  
	// add the policy to the Function's role
	 // This provides access to the lambda function to S3 bucket
	 lambda_rename_move_files.role?.attachInlinePolicy(
	  new iam.Policy(this, `${env_config.appName}-s3-permissions-to-lambda`, {
		statements: [lambda_permissions_to_s3],
	  }),
	);
  
	// Adding a trigger to the lambda function. The function is triggered as soon as a file is added to the bucket
	const s3PutEventSource = new lambdaEventSources.S3EventSource( stage_bucket , {
	  events: [
		s3.EventType.OBJECT_CREATED
	  ]
	});
	lambda_rename_move_files.addEventSource(s3PutEventSource);


  }
}