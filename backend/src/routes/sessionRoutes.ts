import { Router } from 'express';
import { SessionController } from '../controllers/SessionController';

const router = Router();
const sessionController = new SessionController();

router.post('/', sessionController.createSession.bind(sessionController));
router.get('/:sessionId', sessionController.getSession.bind(sessionController));

export default router;

