import express from 'express';
import { router as healthRouter } from './routes/health';
import fetch from "node-fetch";


const app = express();
const port = Number(process.env.PORT || 8080);


app.use(express.json());
app.use('/health', healthRouter);





app.get('/sites', async (req, res) => {

  const targetUrl = "http://sites.us-central1.run.internal";

  const resp = await fetch(targetUrl, {});

  const data = await resp.json();

  console.log(data);

  res.json({ message: 'Calling Remote Sites Service on Cloud Run', data });
});

app.get('/users', async (req, res) => {

  const targetUrl = "http://users.us-central1.run.internal";

  const resp = await fetch(targetUrl, {});

  const data = await resp.json();

  console.log(data);

  res.json({ message: 'Calling Remote Users Service on Cloud Run', data });
});


app.get('/', (req, res) => {
  res.json({ message: 'Gateway Service on Cloud Run' });
});


app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});


export default app;