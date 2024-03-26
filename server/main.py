from flask import Flask, jsonify
from flask_cors import CORS
import json
# import boto3

app = Flask(__name__)
cors = CORS(app, origins="*")  # CHANGE THIS WHEN PROPER ROUTE IS ESTABLISHED

@app.route("/api/questions", methods=['GET'])
def users():
    
    with open ("./test-data/COMPTIA A+ core 1 exam 220-1101", 'r') as file:
        
        testData = json.load(file)
        print("***************")
        print("***************")
        print("***************", type(testData[0][0]))
        print("***************")
        print("***************")
        
    return jsonify(testData[0])

@app.route("/upload", methods=['POST'])
def upload_to_s3():
    pass

    
if __name__ == "__main__":
    app.run(debug=True, port=8080)