import boto3

client = boto3.client('datasync', region_name='eu-west-1')

def lambda_handler(event,context):
    response = client.start_task_execution(TaskArn='arn:aws:datasync:eu-west-1:681718253798:task/task-0201baabab0b6efa7')