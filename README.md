# ExamScribe

**ExamScribe** is a Python application that generates practice exams from PDF files containing practice questions. It utilizes AWS services like Lambda, S3, and DynamoDB to provide a scalable and serverless solution.

**Note:** This project is a work in progress, and a publicly accessible version is currently under development.

## Overview

The application works as follows:

1. A PDF file containing practice questions is uploaded to an S3 bucket.
2. The S3 upload triggers an AWS Lambda function written in Python.
3. The Lambda function scrapes the text from the PDF, parses the questions, and stores the data in a DynamoDB table.
4. Users can generate randomized quizzes from the stored questions using the application.

Two modes are available: **"Test"** and **"Practice."**

- In **"Test"** mode, users answer all questions, and then the application provides a grade.
- In **"Practice"** mode, users receive immediate feedback for each question submitted.

## Features

- Generates practice exams from PDF files containing practice questions.
- Supports two modes: **"Test"** and **"Practice."**
- Utilizes AWS services (Lambda, S3, DynamoDB) for a scalable and serverless architecture.

## Upcoming Features

- Web front-end for users to interact and upload their own PDFs.
- Ability to customize exams and change the number of questions per section.
- Ability to store and retrieve results from previous quizzes.

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.

## License

This project is licensed under the MIT License.

## Contact

For any questions or issues, please contact me at [elliotmrgn@gmail.com](mailto:elliotmrgn@gmail.com).