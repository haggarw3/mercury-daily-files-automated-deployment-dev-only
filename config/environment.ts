export interface cdk_environment {
  
    readonly environment: string;  // Environment - Integration/Development/Production
    readonly appName: string; // TODO replace the project_name in main stack with this 
    readonly githubRepoName?: string; // ? means optional parameter
    readonly branchName: string;
    readonly awsEnv: {
      readonly account_name: string;
      readonly account_id?: string;
      readonly region: string;
    };
    readonly redshift: {
      readonly host?: string;
      readonly port?: string; 
      readonly user?: string;
      readonly password?: string;
      readonly dbName?: string;
      readonly cluster_identifier: string;
      readonly apiRole?: string;
    };
    readonly pipeline: {
      readonly jira_project: number;
      readonly jira_prefix: string;
    };
    readonly vpc_connection: string;
    readonly envRole?: string;
    readonly cross_account_extraction_role?: string; // ? means optional parameter
    readonly extractionPath?: string;
  }

const env: cdk_environment = {
     environment: 'development',  // Environment - Integration/Development/Production - AWS dev
     appName: 'cdk-mercury-daily-files',
     githubRepoName:'mercury-aws-cdk-single-stack',
     branchName: 'dev',
     awsEnv: {
       account_name: 'datalake-dev',
      //  account_id: '423225241' // hidden as this parameter will be provided using the secrets manager 
       region: 'us-east-1',
    },
    redshift: {
      // host: 'redshift-cluster-1.cwxx3jnng4yo.us-east-1.redshift.amazonaws.com',
      // port: '****', // hidden as this parameter will be provided using the secrets manager 
      // user: '*******', // hidden as this parameter will be provided using the secrets manager 
      // password: '***********', // hidden as this parameter will be provided using the secrets manager 
      // dbName: '***', // hidden as this parameter will be provided using the secrets manager 
      cluster_identifier: 'redshift-cluster-1',
      // apiRole: 'arn:aws:iam::464340339497:role/Redshift-data-api-role', // hidden as this parameter will be provided using the secrets manager 
    },
    pipeline: {
      jira_project: 123,
      jira_prefix: '123',
    },
    vpc_connection: 'load-redshift',
    envRole: 'arn:aws:iam::464340339497:role/service-role/AWSGlueServiceRole-Datalake'
  }

export {env};