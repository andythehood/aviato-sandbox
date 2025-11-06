import { Router } from 'express';


export const router = Router();


router.get('/', (_req, res) => {
res.status(200).json({ status: 'ok' });
});