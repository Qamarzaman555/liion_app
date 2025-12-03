import { Router } from 'express';
import { LogController } from '../controllers/LogController';

const router = Router();
const logController = new LogController();

router.post('/batch', logController.batchLog.bind(logController));
router.get('/session/:sessionId', logController.getSessionLogs.bind(logController));

export default router;

