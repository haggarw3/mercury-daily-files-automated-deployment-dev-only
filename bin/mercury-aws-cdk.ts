#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { MercuryAwsCdkStack } from '../lib/mercury-aws-cdk-stack';


const app = new cdk.App();
const resources = new MercuryAwsCdkStack(app, 'MercuryAwsCdkStack', {});
