import fitz


def lambda_handler(event, context):
    # Initialize a session using Amazon DynamoDB
    # dynamodb = boto3.resource("dynamodb")

    # # Specify the table
    # table = dynamodb.Table("QuestionBanks")

    # # Assuming 'event' contains the book data
    # book_data = event["book_data"]

    # # Insert the book data into the table
    # response = table.put_item(Item=book_data)

    #return response
    print('🚀 ~ "Hello World":", "Hello World')
    return "Hello World"



lambda_handler(1, 2)
