import * as React from 'react';
import Typography from '@mui/material/Typography';
import Container from '@mui/material/Container';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import QuizList from '../../components/QuizList'
import { Button } from '@mui/material';

import { Link } from "react-router-dom";

function handleSubmit(){
  
}

function Copyright(props) {
  return (
    <Typography variant="body2" color="text.secondary" align="center" {...props}>
      {'Copyright © '}
      {/* <Link color="inherit" href="https://mui.com/">
        Your Website
      </Link>{' '} */}
      {new Date().getFullYear()}
      {'.'}
    </Typography>
  );
}

export default function Dashboard() {
  const [selectedItem, setSelectedItem] = React.useState({})
  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Grid container spacing={3}>
        {/* Chart */}
        <Grid item xs={12} md={6}>
          <Paper
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 240,
            }}
          >

            {/* Display Selected Item Details */}
            {/* TODO: Build out details */}
            {selectedItem.title}
            <br/>
            <br/>
            {selectedItem.totalQuestions}
          </Paper>
        </Grid>
        {/* Settings */}
        <Grid item xs={12} md={6}>
          <Paper
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 240,
            }}
          >

            {/* TODO: Change this to display settings */}

            {Object.keys(selectedItem).length > 0 ? 
              <Link to='/quiz'>
                <Button>Submit</Button>
              </Link> 
            : null}
          </Paper>
        </Grid>

        {/* Quiz List */}
        {/* TODO: Edit data of table and read in from */}
        <Grid item xs={12}>
          <Paper sx={{ p: 2, display: 'flex', flexDirection: 'column' }}>
            <QuizList onSelectedItem = {setSelectedItem} populateData = {""}/>
          </Paper>
        </Grid>
      </Grid>
      {/* <Copyright sx={{ pt: 4 }} /> */}
    </Container>
  )
}