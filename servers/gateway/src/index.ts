import express from 'express';
import { router as healthRouter } from './routes/health';


const app = express();
const port = Number(process.env.PORT || 8080);


app.use(express.json());
app.use('/health', healthRouter);


app.get('/', (req, res) => {
res.json({ message: 'Gateway Service on Cloud Run' });
});


app.listen(port, () => {
console.log(`Server listening on port ${port}`);
});


export default app;