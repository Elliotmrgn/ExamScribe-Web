import React, { useEffect, useState } from "react";
import axios from "axios";
import QuizQuestion from "../../components/QuizQuestion";

const Quiz = () => {
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState(null);
  const [questionBank, setQuestionBank] = useState([]);

  const fetchQuestionBank = async () => {
    try {
      const response = await axios.get("http://localhost:8080/api/questions");
      setQuestionBank(response.data);
    } catch (error) {
      console.error("Error fetching question bank:", error);
    }
  };

  useEffect(() => {
    fetchQuestionBank();
  }, []);

  const handleAnswerSelected = (answer) => {
    setSelectedAnswer(answer);
  };

  const handleNextQuestion = () => {
    // Check answer correctness, handle score, etc.
    setSelectedAnswer(null);
    setCurrentQuestionIndex((prevIndex) => prevIndex + 1);
  };

  const currentQuestion = questionBank[currentQuestionIndex];

  return (
    <div>
      {currentQuestion && (
        <QuizQuestion
          question={currentQuestion.question_text}
          choices={currentQuestion.choices}
          selectedAnswer={selectedAnswer}
          onAnswerSelected={handleAnswerSelected}
          onNextQuestion={handleNextQuestion}
        />
      )}
    </div>
  );
};

export default Quiz;
