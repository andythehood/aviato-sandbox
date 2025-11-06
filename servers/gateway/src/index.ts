import express from 'express';
import { router as healthRouter } from './routes/health';
import fetch from "node-fetch";


const app = express();
const port = Number(process.env.PORT || 8080);


app.use(express.json());
app.use('/health', healthRouter);





app.get('/sites', async (req, res) => {

  const targetUrl = "https://sites-537073366159.us-central1.run.app";

  const resp = await fetch(targetUrl, {});

  const data = await resp.json();

  console.log(data);

  res.json({ message: 'Calling Remote Sites Service on Cloud Run', data });
});

app.get('/users', async (req, res) => {

  try {


    const targetUrl = "https://users-537073366159.us-central1.run.app";

    const resp = await fetch(targetUrl, {});

    const data = await resp.json();

    console.log(data);

    res.json({ message: 'Calling Remote Users Service on Cloud Run', data });
  }
  catch (err) {
    res.json({ message: 'Error Calling Remote Users Service on Cloud Run', err });

  }
});


app.get('/', (req, res) => {
  res.json({ message: 'Gateway Service on Cloud Run' });
});


app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});


export default app;