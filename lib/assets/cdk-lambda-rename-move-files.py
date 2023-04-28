import json
from boto3 import client
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    
    conn = client('s3')
    source_bucket = 'cdk-mercury-daily-files-temp'
    dest_bucket = 'cdk-mercury-daily-files-csv'
    
    # delete any files in the daily folder of bucket - mercury_oncall_csv
    
    try:
        items_dest = conn.list_objects(Bucket = dest_bucket, Prefix ='daily/')['Contents']
        if len(items_dest) > 0:  # ie if there are files in the folder 
            for item in items_dest:
                conn.delete_object(Bucket = dest_bucket , Key = item['Key'])
    except:
        print('no files in destination bucket - daily folder')
            
    # Find the last modified file in mercury_oncall
    
    items_source = conn.list_objects(Bucket = source_bucket, Prefix ='daily/')['Contents']
    last_modifieds = [ item['LastModified']  for item in items_source]
    max_lastmodified = max(last_modifieds)

    for item in items_source:
        if item['LastModified'] == max_lastmodified:
            source_path = source_bucket + '/' + item['Key']
            year = str(item['LastModified'].year)
            month_num  = item['LastModified'].month
            if month_num <= 9:
                month_num = '0'+str(month_num)
            else:
                month_num = str(month_num)
            day_num = item['LastModified'].day
            if day_num <= 9:
                day_num = '0'+str(day_num)
            else:
                day_num = str(day_num)
            new_name  = 'daily/SES_EXTRACT_ERS_INFO-' + year + month_num + day_num + '.csv'
            conn.copy_object(Bucket= dest_bucket, CopySource=source_path , Key=new_name)
        else:
            pass
                
        
    
    return {
        'statusCode': 200,
        'body': json.dumps('File name changed')
    }

