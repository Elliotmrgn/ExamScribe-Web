import boto3
import urllib.parse
import logging
from typing import Dict
from pdf_processing import PDF_Processing


def lambda_handler(event: Dict, context) -> Dict:
    logging.getLogger().setLevel(logging.INFO)

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
        # Build the chapter map
        pdf.build_chapters()
        # Extract the questions
        pdf.build_question_bank()
        
        userid = "1" # this will change when auth is implemented
        
        # -------------USER DATA DB------------------
        dynamodb = boto3.client("dynamodb")
        user_table = "UserDataTable"
        
        data_for_user_table = {
            "UserID": {"S": userid},
            "QuizID": {"S": pdf.quiz_id},
            "Title": {"S": pdf.title},
            "Author": {"S": pdf.author},
            "Creation Date": {"S": pdf.creation_date},
            "Total Questions": {"N": str(pdf.total_questions)},
        }
        try:
            dynamodb.put_item(TableName=user_table, Item=data_for_user_table)
            logging.info(
                f"Item with ID {data_for_user_table['QuizID']['S']} added successfully to {user_table}."
            )
        except Exception as e:
            logging.info(f"Error adding item to {user_table}: {e}")

        # ------------QUESTION BANK DB---------------
        dynamodb = boto3.resource("dynamodb")
        question_bank_table = dynamodb.Table("QuestionBankTable")
        try:
            with question_bank_table.batch_writer() as batch:
                for i, (chapter_name, questions) in enumerate(pdf.question_bank.items()):
                    batch.put_item(Item={
                        "QuizID": pdf.quiz_id,
                        "ChapterNum": i + 1,
                        "ChapterTitle": chapter_name,
                        "Questions": questions,})
            logging.info(
                f"Items with ID {pdf.quiz_id} added successfully to {question_bank_table}."
            )
            
        except Exception as e:
            logging.info(f"Error adding item to {question_bank_table}: {e}")

        return {"statusCode": 200, "body": "PDF processed successfully"}
    
    except Exception as e:
        logging.info(f"Error processing PDF {object_key}: {str(e)}")
        return {
            "statusCode": 500,
            "body": f"Error processing PDF {object_key}: {str(e)}",
        }