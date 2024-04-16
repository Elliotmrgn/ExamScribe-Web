import boto3
import urllib.parse
import json
from pdf_processing import PDF_Processing


def lambda_handler(event, context):
    print("** EVENT:  ", event)
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
    s3_client = boto3.client('s3')
    
    try:
        # Get the PDF object from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        # Read the content of the PDF
        pdf_content = response['Body'].read()
        # Extract text from the PDF
        pdf = PDF_Processing(pdf_content)
        pdf.build_chapters()
        pdf.build_question_bank()
        userid = "1" # this will change when auth is implemented
        
        return "SUCCEEDED PROCESSING PDF"
        
        data_for_user_table = {
            "UserID": {'S': userid},
            "QuizID": {'S': pdf.quiz_id},
            "Title": {'S': pdf.title},
            "Author": {'S': pdf.author},
            "Creation Date": {'S': pdf.creation_date},
            "Total Questions": {'N': pdf.total_questions}
        }
    
        data_for_question_bank_table = {
            "QuizID": {'S':pdf.quiz_id},
            "Title": {'S':pdf.title},
            "Questions": {'L':pdf.question_bank}
        }
        
        dynamodb = boto3.client('dynamodb')
        
        user_table = "UserDataTable"
        question_bank_table = "QuestionBankTable"
        
        try:
            response = dynamodb.put_item(
                TableName=user_table,
                Item=data_for_user_table
            )
            print(f"Item with ID {data_for_user_table['QuizID']['S']} added successfully to {user_table}.")
        except Exception as e:
            print(f"Error adding item to {user_table}: {e}")
            
        try:
            response = dynamodb.put_item(
                TableName = question_bank_table,
                Item = data_for_question_bank_table
            )
            print(f"Item with ID {data_for_question_bank_table['QuizID']['S']} added successfully to {question_bank_table}.")
        except Exception as e:
            print(f"Error adding item to {question_bank_table}: {e}")

        return {
            'statusCode': 200,
            'body': json.dumps('PDF processed successfully')
        }
    except Exception as e:
        print(f"Error processing PDF {object_key}: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error processing PDF {object_key}: {str(e)}")
        }