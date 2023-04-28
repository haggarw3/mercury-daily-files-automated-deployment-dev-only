import sys
import pg
from awsglue.utils import getResolvedOptions
from boto3 import client

args = getResolvedOptions(sys.argv, [
    'user',
    'dbname',
    'password',
    'host',
    'port',
    's3_load_sql_bucket',
    's3_load_sql_key'
])

user = args['user']
password = args['password']
dbname = args['dbname']
host = args['host']
port = args['port']
s3_load_sql_bucket = args['s3_load_sql_bucket']
s3_load_sql_key = args['s3_load_sql_key']

datalake_s3_client = client('s3')
sql_object = datalake_s3_client.get_object(Bucket=s3_load_sql_bucket, Key=s3_load_sql_key)
sql_body = sql_object['Body'].read().decode('utf-8')

rs_conn_string = "host=%s port=%s dbname=%s user=%s password=%s" % (host, port, dbname, user, password)
rs_conn = pg.connect(dbname=rs_conn_string)
rs_conn.query("set statement_timeout = 1200000")
print("Running SQL")
response = rs_conn.query(sql_body)
print(response)
