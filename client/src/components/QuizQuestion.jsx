import React from 'react';
import { Typography, FormControl, RadioGroup, FormControlLabel, Radio, Button } from '@mui/material';

const QuizQuestion = ({ question, choices, selectedAnswer, onAnswerSelected, onNextQuestion }) => {

  return (
    <div>
      <Typography variant="h5" gutterBottom>
        {question}
      </Typography>
      <FormControl component="fieldset">
        <RadioGroup
          aria-label="quiz"
          name="quiz"
          value={selectedAnswer}
          onChange={(event) => onAnswerSelected(event.target.value)}
        >
          {choices.map((choice) => (
            
            <FormControlLabel key={choice[0]} value={choice[1]} control={<Radio />} label={choice[1]} />
          ))}
        </RadioGroup>
      </FormControl>
      <Button variant="contained" onClick={onNextQuestion}>
        Next
      </Button>
    </div>
  );
};

export default QuizQuestion;