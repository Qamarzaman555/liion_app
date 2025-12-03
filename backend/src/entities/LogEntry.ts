import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    ManyToOne,
    JoinColumn,
    Index,
} from 'typeorm';
import { Session } from './Session';

@Entity('log_entries')
@Index(['sessionId', 'createdAt'])
@Index(['level'])
export class LogEntry {
    @PrimaryGeneratedColumn('increment')
    id: number;

    @Column({ type: 'int' })
    sessionId: number;

    @ManyToOne(() => Session, (session: Session) => session.logs, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'sessionId' })
    session: Session;

    @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
    ts: Date;

    @Column({ type: 'varchar', length: 50 })
    level: string;

    @Column({ type: 'text' })
    message: string;

    @CreateDateColumn({ type: 'timestamp' })
    createdAt: Date;
}

